"""
MCP服务器管理器
统一管理所有MCP服务器的启动、注册和路由
"""

import asyncio
import json
import logging
from typing import Dict, List, Any, Optional
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

from .base_server import service_registry
from .molecular_generator import MolecularGeneratorMCP
from .schrodinger import SchrodingerMCP
from .admet_predictor import ADMETMCPServer
from .other_tools import MDSimulatorMCP, TorsionScannerMCP, SubstructureSearcherMCP, SynthesisAssessorMCP

logger = logging.getLogger(__name__)

class MCPManager:
    """MCP服务器管理器"""
    
    def __init__(self):
        self.servers: Dict[str, Any] = {}
        self.app = FastAPI(title="AI Drug Discovery MCP Gateway", version="1.0.0")
        self._setup_routes()
        self._setup_cors()
        
    def _setup_cors(self):
        """设置CORS"""
        self.app.add_middleware(
            CORSMiddleware,
            allow_origins=["*"],
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )
        
    def _setup_routes(self):
        """设置API路由"""
        
        @self.app.get("/")
        async def root():
            return {
                "message": "AI Drug Discovery MCP Gateway",
                "version": "1.0.0",
                "available_servers": list(self.servers.keys())
            }
        
        @self.app.get("/servers")
        async def list_servers():
            """列出所有可用的MCP服务器"""
            servers_info = {}
            for name, server in self.servers.items():
                servers_info[name] = {
                    "name": server.name,
                    "version": server.version,
                    "capabilities": server.capabilities,
                    "tools": list(server.tools.keys())
                }
            return servers_info
        
        @self.app.get("/servers/{server_name}/tools")
        async def list_tools(server_name: str):
            """列出特定服务器的工具"""
            if server_name not in self.servers:
                raise HTTPException(status_code=404, detail=f"Server {server_name} not found")
            
            server = self.servers[server_name]
            tools_info = []
            for tool in server.tools.values():
                tools_info.append({
                    "name": tool.name,
                    "description": tool.description,
                    "input_schema": tool.input_schema,
                    "output_schema": tool.output_schema
                })
            return {"tools": tools_info}
        
        @self.app.post("/servers/{server_name}/tools/{tool_name}")
        async def call_tool(server_name: str, tool_name: str, request_data: dict):
            """调用特定工具"""
            if server_name not in self.servers:
                raise HTTPException(status_code=404, detail=f"Server {server_name} not found")
            
            server = self.servers[server_name]
            if tool_name not in server.tools:
                raise HTTPException(status_code=404, detail=f"Tool {tool_name} not found in server {server_name}")
            
            try:
                result = await server.call_tool(tool_name, request_data)
                return {
                    "success": True,
                    "result": result,
                    "server": server_name,
                    "tool": tool_name
                }
            except Exception as e:
                logger.error(f"Error calling tool {tool_name} on server {server_name}: {e}")
                raise HTTPException(status_code=500, detail=str(e))
        
        @self.app.post("/workflow")
        async def run_workflow(workflow_data: dict):
            """运行工作流"""
            return await self._run_workflow(workflow_data)
        
        @self.app.get("/health")
        async def health_check():
            """健康检查"""
            return {
                "status": "healthy",
                "servers_count": len(self.servers),
                "active_servers": [name for name, server in self.servers.items()]
            }
    
    async def register_servers(self):
        """注册所有MCP服务器"""
        servers_to_register = [
            ("molecular_generator", MolecularGeneratorMCP()),
            ("schrodinger", SchrodingerMCP()),
            ("admet_predictor", ADMETMCPServer()),
            ("md_simulator", MDSimulatorMCP()),
            ("torsion_scanner", TorsionScannerMCP()),
            ("substructure_searcher", SubstructureSearcherMCP()),
            ("synthesis_assessor", SynthesisAssessorMCP())
        ]
        
        for name, server in servers_to_register:
            self.servers[name] = server
            
            # 注册到服务注册中心
            capabilities = []
            for tool_name in server.tools.keys():
                capabilities.append(tool_name)
            
            service_registry.register_service(
                name=name,
                endpoint=f"http://localhost:8000/servers/{name}",
                capabilities=capabilities
            )
            
            logger.info(f"Registered MCP server: {name} with {len(server.tools)} tools")
    
    async def _run_workflow(self, workflow_data: dict) -> dict:
        """运行工作流"""
        steps = workflow_data.get("steps", [])
        results = {}
        
        for step in steps:
            server_name = step.get("server")
            tool_name = step.get("tool")
            arguments = step.get("arguments", {})
            step_id = step.get("id", f"{server_name}_{tool_name}")
            
            # 处理参数中的引用
            processed_args = self._process_workflow_arguments(arguments, results)
            
            try:
                if server_name in self.servers:
                    result = await self.servers[server_name].call_tool(tool_name, processed_args)
                    results[step_id] = result
                else:
                    raise Exception(f"Server {server_name} not found")
            except Exception as e:
                logger.error(f"Workflow step {step_id} failed: {e}")
                results[step_id] = {"error": str(e)}
        
        return {
            "workflow_id": workflow_data.get("id", "unknown"),
            "status": "completed",
            "results": results
        }
    
    def _process_workflow_arguments(self, arguments: dict, previous_results: dict) -> dict:
        """处理工作流参数中的引用"""
        processed = {}
        
        for key, value in arguments.items():
            if isinstance(value, str) and value.startswith("$"):
                # 引用前一步的结果
                ref_path = value[1:].split(".")
                ref_result = previous_results
                
                try:
                    for path_part in ref_path:
                        ref_result = ref_result[path_part]
                    processed[key] = ref_result
                except (KeyError, TypeError):
                    logger.warning(f"Could not resolve reference: {value}")
                    processed[key] = value
            else:
                processed[key] = value
        
        return processed
    
    async def start_server(self, host: str = "0.0.0.0", port: int = 8000):
        """启动MCP网关服务器"""
        await self.register_servers()
        
        config = uvicorn.Config(
            app=self.app,
            host=host,
            port=port,
            log_level="info"
        )
        server = uvicorn.Server(config)
        
        logger.info(f"Starting MCP Gateway on {host}:{port}")
        logger.info(f"Registered {len(self.servers)} MCP servers")
        
        await server.serve()

# 全局MCP管理器实例
mcp_manager = MCPManager()

async def main():
    """主函数"""
    await mcp_manager.start_server()

if __name__ == "__main__":
    asyncio.run(main())

