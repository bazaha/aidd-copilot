"""
Docker容器启动脚本
用于在Docker环境中启动所有服务
"""

import asyncio
import subprocess
import sys
import time
import os
import signal
import threading
from typing import List, Optional

# 全局进程列表，用于清理
processes: List[subprocess.Popen] = []

def signal_handler(signum, frame):
    """信号处理器，用于优雅关闭"""
    print(f"\nReceived signal {signum}, shutting down gracefully...")
    cleanup_processes()
    sys.exit(0)

def cleanup_processes():
    """清理所有子进程"""
    for process in processes:
        if process.poll() is None:  # 进程仍在运行
            print(f"Terminating process {process.pid}...")
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                print(f"Force killing process {process.pid}...")
                process.kill()

def start_fake_api():
    """启动Fake API服务"""
    print("🔬 Starting Fake API Server on port 8288...")
    
    script_dir = "/app"
    fake_api_path = os.path.join(script_dir, "fake_apis", "fake_api_server.py")
    
    env = os.environ.copy()
    env["PYTHONPATH"] = script_dir
    
    process = subprocess.Popen([
        sys.executable, fake_api_path
    ], 
    cwd=script_dir,
    env=env,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    universal_newlines=True
    )
    
    processes.append(process)
    
    # 在后台线程中处理输出
    def log_output():
        if process.stdout:
            for line in process.stdout:
                print(f"[FAKE-API] {line.strip()}")
    
    threading.Thread(target=log_output, daemon=True).start()
    return process

def start_web_server():
    """启动Web服务器"""
    print("🌍 Starting Web Server on port 8080...")
    
    web_dir = "/app/web_interface"
    
    process = subprocess.Popen([
        sys.executable, "-m", "http.server", "8080"
    ],
    cwd=web_dir,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    universal_newlines=True
    )
    
    processes.append(process)
    
    # 在后台线程中处理输出
    def log_output():
        if process.stdout:
            for line in process.stdout:
                print(f"[WEB-SERVER] {line.strip()}")
    
    threading.Thread(target=log_output, daemon=True).start()
    return process

async def start_mcp_gateway():
    """启动MCP网关"""
    print("🧠 Starting MCP Gateway on port 8088...")
    
    # 添加项目路径到Python路径
    script_dir = "/app"
    sys.path.insert(0, script_dir)
    
    try:
        from mcp_servers.manager import mcp_manager
        # 启动MCP网关
        await mcp_manager.start_server(host="0.0.0.0", port=8088)
    except Exception as e:
        print(f"❌ Failed to start MCP Gateway: {e}")
        raise

def wait_for_service(port: int, service_name: str, max_attempts: int = 30):
    """等待服务启动"""
    import socket
    
    print(f"⏳ Waiting for {service_name} on port {port}...")
    
    for attempt in range(max_attempts):
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(1)
            result = sock.connect_ex(('localhost', port))
            sock.close()
            
            if result == 0:
                print(f"✅ {service_name} is ready on port {port}")
                return True
                
        except Exception:
            pass
            
        time.sleep(1)
    
    print(f"❌ Timeout waiting for {service_name} on port {port}")
    return False

def main():
    """主函数"""
    print("🚀 AI Drug Discovery Platform - Docker Container Starting")
    print("=" * 60)
    
    # 注册信号处理器
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        # 启动Fake API服务
        fake_api_process = start_fake_api()
        time.sleep(3)
        
        # 检查Fake API是否启动成功
        if not wait_for_service(8288, "Fake API Server", 10):
            print("❌ Failed to start Fake API Server")
            return 1
        
        # 启动Web服务器
        web_process = start_web_server()
        time.sleep(2)
        
        # 检查Web服务器是否启动成功
        if not wait_for_service(8080, "Web Server", 10):
            print("❌ Failed to start Web Server")
            return 1
        
        print("\n🎉 Services Status:")
        print("   • Fake API Server: ✅ Running on port 8288")
        print("   • Web Server:      ✅ Running on port 8080")
        print("   • MCP Gateway:     🔄 Starting on port 8088...")
        print()
        
        # 启动MCP网关（这会阻塞直到服务停止）
        asyncio.run(start_mcp_gateway())
        
    except KeyboardInterrupt:
        print("\n🛑 Received interrupt signal")
    except Exception as e:
        print(f"❌ Error: {e}")
        return 1
    finally:
        cleanup_processes()
    
    return 0

if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)
