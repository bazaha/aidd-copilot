"""
MCP服务器基础类
提供统一的MCP协议实现
"""

import asyncio
import json
import logging
from abc import ABC, abstractmethod
from typing import Dict, List, Any, Optional
from dataclasses import dataclass
from datetime import datetime

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class MCPTool:
    """MCP工具定义"""
    name: str
    description: str
    input_schema: Dict[str, Any]
    output_schema: Dict[str, Any]

@dataclass
class MCPRequest:
    """MCP请求格式"""
    method: str
    params: Dict[str, Any]
    id: Optional[str] = None

@dataclass
class MCPResponse:
    """MCP响应格式"""
    result: Optional[Dict[str, Any]] = None
    error: Optional[Dict[str, Any]] = None
    id: Optional[str] = None

class MCPError(Exception):
    """MCP错误类"""
    def __init__(self, code: int, message: str, data: Optional[Dict] = None):
        self.code = code
        self.message = message
        self.data = data or {}
        super().__init__(f"MCP Error {code}: {message}")

class BaseMCPServer(ABC):
    """MCP服务器基础类"""
    
    def __init__(self, name: str, version: str = "1.0.0"):
        self.name = name
        self.version = version
        self.tools: Dict[str, MCPTool] = {}
        self.capabilities = {
            "tools": True,
            "resources": False,
            "prompts": False
        }
        
    def register_tool(self, tool: MCPTool):
        """注册工具"""
        self.tools[tool.name] = tool
        logger.info(f"Registered tool: {tool.name}")
        
    async def handle_request(self, request_data: str) -> str:
        """处理MCP请求"""
        try:
            request_json = json.loads(request_data)
            request = MCPRequest(**request_json)
            
            if request.method == "initialize":
                response = await self._handle_initialize(request.params)
            elif request.method == "tools/list":
                response = await self._handle_list_tools()
            elif request.method == "tools/call":
                response = await self._handle_call_tool(request.params)
            else:
                raise MCPError(404, f"Method not found: {request.method}")
                
            return json.dumps({
                "result": response,
                "id": request.id
            })
            
        except MCPError as e:
            return json.dumps({
                "error": {
                    "code": e.code,
                    "message": e.message,
                    "data": e.data
                },
                "id": getattr(request, 'id', None)
            })
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            return json.dumps({
                "error": {
                    "code": 500,
                    "message": "Internal server error",
                    "data": {"details": str(e)}
                },
                "id": getattr(request, 'id', None)
            })
    
    async def _handle_initialize(self, params: Dict) -> Dict:
        """处理初始化请求"""
        return {
            "protocolVersion": "2024-11-05",
            "capabilities": self.capabilities,
            "serverInfo": {
                "name": self.name,
                "version": self.version
            }
        }
    
    async def _handle_list_tools(self) -> Dict:
        """处理工具列表请求"""
        tools_list = []
        for tool in self.tools.values():
            tools_list.append({
                "name": tool.name,
                "description": tool.description,
                "inputSchema": tool.input_schema
            })
        return {"tools": tools_list}
    
    async def _handle_call_tool(self, params: Dict) -> Dict:
        """处理工具调用请求"""
        tool_name = params.get("name")
        arguments = params.get("arguments", {})
        
        if tool_name not in self.tools:
            raise MCPError(404, f"Tool not found: {tool_name}")
        
        try:
            result = await self.call_tool(tool_name, arguments)
            return {
                "content": [
                    {
                        "type": "text",
                        "text": json.dumps(result, indent=2)
                    }
                ]
            }
        except Exception as e:
            raise MCPError(500, f"Tool execution failed: {str(e)}")
    
    @abstractmethod
    async def call_tool(self, name: str, arguments: Dict) -> Dict:
        """执行具体工具功能 - 子类必须实现"""
        pass

class ServiceRegistry:
    """服务注册中心"""
    
    def __init__(self):
        self.services: Dict[str, Dict] = {}
        
    def register_service(self, name: str, endpoint: str, capabilities: List[str]):
        """注册服务"""
        self.services[name] = {
            "endpoint": endpoint,
            "capabilities": capabilities,
            "status": "active",
            "registered_at": datetime.now().isoformat()
        }
        logger.info(f"Service registered: {name} at {endpoint}")
        
    def unregister_service(self, name: str):
        """注销服务"""
        if name in self.services:
            del self.services[name]
            logger.info(f"Service unregistered: {name}")
            
    def discover_services(self, capability_filter: Optional[List[str]] = None) -> List[Dict]:
        """发现服务"""
        if not capability_filter:
            return list(self.services.values())
            
        filtered_services = []
        for service in self.services.values():
            if any(cap in service["capabilities"] for cap in capability_filter):
                filtered_services.append(service)
                
        return filtered_services
    
    def get_service(self, name: str) -> Optional[Dict]:
        """获取特定服务"""
        return self.services.get(name)

# 全局服务注册中心实例
service_registry = ServiceRegistry()

