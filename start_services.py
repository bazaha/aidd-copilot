"""
启动脚本
用于启动MCP服务器和Fake API服务
"""

import asyncio
import subprocess
import sys
import time
import os

def start_fake_api():
    """启动Fake API服务"""
    print("Starting Fake API Server...")
    script_dir = os.path.dirname(os.path.abspath(__file__))
    fake_api_path = os.path.join(script_dir, "fake_apis", "fake_api_server.py")
    
    # 启动Fake API服务器
    process = subprocess.Popen([
        sys.executable, fake_api_path
    ], cwd=script_dir)
    
    return process

async def start_mcp_gateway():
    """启动MCP网关"""
    print("Starting MCP Gateway...")
    
    # 添加项目路径到Python路径
    script_dir = os.path.dirname(os.path.abspath(__file__))
    sys.path.insert(0, script_dir)
    
    from mcp_servers.manager import mcp_manager
    
    # 启动MCP网关
    await mcp_manager.start_server(host="0.0.0.0", port=8088)

def main():
    """主函数"""
    print("AI Drug Discovery Platform - Starting Services")
    print("=" * 50)
    
    # 启动Fake API服务
    fake_api_process = start_fake_api()
    
    # 等待一下让Fake API启动
    time.sleep(2)
    
    try:
        # 启动MCP网关
        asyncio.run(start_mcp_gateway())
    except KeyboardInterrupt:
        print("\nShutting down services...")
        fake_api_process.terminate()
        fake_api_process.wait()
        print("Services stopped.")

if __name__ == "__main__":
    main()

