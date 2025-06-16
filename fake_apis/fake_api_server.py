"""
Fake API服务
为演示目的提供模拟的外部API服务
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import random
import time
import json
from datetime import datetime
import uuid

app = Flask(__name__)
CORS(app)  # 允许跨域请求

# 模拟数据库
fake_compounds_db = []
fake_targets_db = [
    {"id": "EGFR", "name": "Epidermal Growth Factor Receptor", "type": "kinase"},
    {"id": "VEGFR2", "name": "Vascular Endothelial Growth Factor Receptor 2", "type": "kinase"},
    {"id": "CDK2", "name": "Cyclin-dependent kinase 2", "type": "kinase"},
    {"id": "p38", "name": "p38 MAP kinase", "type": "kinase"},
    {"id": "JNK", "name": "c-Jun N-terminal kinase", "type": "kinase"}
]

@app.route('/')
def home():
    return jsonify({
        "service": "AI Drug Discovery Fake API",
        "version": "1.0.0",
        "endpoints": [
            "/api/compounds/search",
            "/api/compounds/generate", 
            "/api/targets/list",
            "/api/docking/submit",
            "/api/admet/predict",
            "/api/synthesis/analyze"
        ]
    })

@app.route('/api/compounds/search', methods=['POST'])
def search_compounds():
    """搜索化合物"""
    data = request.get_json()
    query = data.get('query', '')
    limit = data.get('limit', 50)
    
    # 模拟搜索延迟
    time.sleep(0.5)
    
    # 生成模拟结果
    results = []
    for i in range(min(limit, random.randint(10, 30))):
        compound = {
            "id": f"FAKE_{random.randint(100000, 999999)}",
            "smiles": generate_fake_smiles(),
            "name": f"Compound_{i+1}",
            "molecular_weight": round(random.uniform(200, 600), 2),
            "logp": round(random.uniform(-2, 6), 2),
            "similarity_score": round(random.uniform(0.7, 1.0), 3),
            "source": "FakeDB"
        }
        results.append(compound)
    
    return jsonify({
        "query": query,
        "total_results": len(results),
        "compounds": results,
        "search_time": 0.5
    })

@app.route('/api/compounds/generate', methods=['POST'])
def generate_compounds():
    """生成新化合物"""
    data = request.get_json()
    target_properties = data.get('target_properties', {})
    num_compounds = data.get('num_compounds', 10)
    
    # 模拟生成时间
    time.sleep(1.0)
    
    compounds = []
    for i in range(num_compounds):
        compound = {
            "id": str(uuid.uuid4()),
            "smiles": generate_fake_smiles(),
            "properties": {
                "molecular_weight": round(random.uniform(200, 500), 2),
                "logp": round(random.uniform(-1, 5), 2),
                "hbd": random.randint(0, 5),
                "hba": random.randint(0, 10),
                "tpsa": round(random.uniform(20, 140), 2)
            },
            "generation_score": round(random.uniform(0.6, 0.95), 3),
            "novelty_score": round(random.uniform(0.5, 0.9), 3)
        }
        compounds.append(compound)
    
    return jsonify({
        "generated_compounds": compounds,
        "generation_time": 1.0,
        "model_version": "FakeGen-v1.0"
    })

@app.route('/api/targets/list', methods=['GET'])
def list_targets():
    """列出可用靶点"""
    return jsonify({
        "targets": fake_targets_db,
        "total_count": len(fake_targets_db)
    })

@app.route('/api/docking/submit', methods=['POST'])
def submit_docking():
    """提交分子对接任务"""
    data = request.get_json()
    ligand_smiles = data.get('ligand_smiles')
    target_id = data.get('target_id')
    
    # 模拟对接计算时间
    time.sleep(2.0)
    
    job_id = str(uuid.uuid4())
    
    # 生成模拟对接结果
    docking_score = round(random.uniform(-12.0, -6.0), 2)
    
    result = {
        "job_id": job_id,
        "status": "completed",
        "ligand_smiles": ligand_smiles,
        "target_id": target_id,
        "docking_score": docking_score,
        "binding_affinity_estimate": {
            "ki_nM": round(10 ** (-docking_score * 0.5) * 1000, 1),
            "confidence": "medium"
        },
        "binding_pose": {
            "coordinates": generate_fake_coordinates(),
            "interactions": generate_fake_interactions()
        },
        "computation_time": 2.0,
        "submitted_at": datetime.now().isoformat()
    }
    
    return jsonify(result)

@app.route('/api/admet/predict', methods=['POST'])
def predict_admet():
    """预测ADMET性质"""
    data = request.get_json()
    smiles = data.get('smiles')
    
    # 模拟ADMET预测时间
    time.sleep(1.5)
    
    result = {
        "smiles": smiles,
        "predictions": {
            "absorption": {
                "caco2_permeability": round(random.uniform(-7.0, -4.0), 2),
                "human_intestinal_absorption": round(random.uniform(0.6, 0.98), 2),
                "bioavailability": round(random.uniform(0.1, 0.9), 2)
            },
            "distribution": {
                "blood_brain_barrier": round(random.uniform(-2.0, 1.0), 2),
                "plasma_protein_binding": round(random.uniform(70, 99), 1),
                "volume_distribution": round(random.uniform(0.5, 10.0), 2)
            },
            "metabolism": {
                "cyp3a4_inhibition": round(random.random(), 2),
                "cyp2d6_inhibition": round(random.random(), 2),
                "metabolic_stability": round(random.uniform(10, 300), 1)
            },
            "excretion": {
                "renal_clearance": round(random.uniform(0.1, 10.0), 2),
                "half_life_hours": round(random.uniform(1, 24), 1)
            },
            "toxicity": {
                "herg_inhibition": round(random.random(), 2),
                "hepatotoxicity": round(random.uniform(0.1, 0.8), 2),
                "mutagenicity": random.choice(["positive", "negative"])
            }
        },
        "overall_score": round(random.uniform(0.3, 0.9), 2),
        "prediction_time": 1.5
    }
    
    return jsonify(result)

@app.route('/api/synthesis/analyze', methods=['POST'])
def analyze_synthesis():
    """分析合成可行性"""
    data = request.get_json()
    target_smiles = data.get('target_smiles')
    
    # 模拟合成分析时间
    time.sleep(2.5)
    
    # 生成模拟合成路线
    num_routes = random.randint(1, 3)
    routes = []
    
    for i in range(num_routes):
        num_steps = random.randint(3, 8)
        steps = []
        
        for j in range(num_steps):
            steps.append({
                "step": j + 1,
                "reaction": random.choice([
                    "Suzuki coupling", "Amide formation", "Reductive amination",
                    "Nucleophilic substitution", "Oxidation", "Reduction"
                ]),
                "yield": round(random.uniform(0.6, 0.95), 2),
                "difficulty": random.choice(["easy", "medium", "hard"]),
                "cost_estimate": round(random.uniform(10, 500), 2)
            })
        
        overall_yield = 1.0
        for step in steps:
            overall_yield *= step["yield"]
        
        routes.append({
            "route_id": i + 1,
            "steps": steps,
            "overall_yield": round(overall_yield, 3),
            "total_cost": sum([step["cost_estimate"] for step in steps]),
            "estimated_time_days": random.randint(5, 30),
            "complexity": random.choice(["low", "medium", "high"])
        })
    
    result = {
        "target_smiles": target_smiles,
        "synthesis_routes": routes,
        "synthesizability_score": round(random.uniform(0.3, 0.9), 2),
        "recommended_route": 1,
        "analysis_time": 2.5
    }
    
    return jsonify(result)

@app.route('/api/workflow/run', methods=['POST'])
def run_workflow():
    """运行工作流"""
    data = request.get_json()
    workflow_steps = data.get('steps', [])
    
    # 模拟工作流执行
    time.sleep(3.0)
    
    results = {}
    for i, step in enumerate(workflow_steps):
        step_id = step.get('id', f'step_{i+1}')
        tool = step.get('tool')
        
        # 根据工具类型生成模拟结果
        if tool == 'molecular_generation':
            results[step_id] = {
                "generated_molecules": [generate_fake_smiles() for _ in range(5)],
                "generation_score": round(random.uniform(0.7, 0.95), 2)
            }
        elif tool == 'docking':
            results[step_id] = {
                "docking_score": round(random.uniform(-12.0, -6.0), 2),
                "binding_pose": "pose_data"
            }
        elif tool == 'admet':
            results[step_id] = {
                "admet_score": round(random.uniform(0.4, 0.9), 2),
                "key_properties": {"logp": 3.2, "mw": 456.7}
            }
        else:
            results[step_id] = {"status": "completed", "data": "mock_result"}
    
    return jsonify({
        "workflow_id": str(uuid.uuid4()),
        "status": "completed",
        "execution_time": 3.0,
        "results": results
    })

def generate_fake_smiles():
    """生成模拟SMILES"""
    templates = [
        "CCc1ccc(cc1)C(=O)Nc2ccc(cc2)S(=O)(=O)N",
        "COc1ccc(cc1)C(=O)Nc2cccc(c2)C(F)(F)F", 
        "Cc1ccc(cc1)S(=O)(=O)Nc2ccc(cc2)C(=O)O",
        "CCN(CC)C(=O)c1ccc(cc1)Oc2ccccc2",
        "Nc1ccc(cc1)S(=O)(=O)Nc2ccc(cc2)C(=O)N",
        "COc1cc(cc(c1OC)OC)C(=O)Nc2ccc(cc2)Cl",
        "Cc1cc(ccc1N)S(=O)(=O)Nc2ccc(cc2)F"
    ]
    return random.choice(templates)

def generate_fake_coordinates():
    """生成模拟坐标"""
    num_atoms = random.randint(15, 30)
    coords = []
    for _ in range(num_atoms):
        coords.append([
            round(random.uniform(-10, 10), 3),
            round(random.uniform(-10, 10), 3), 
            round(random.uniform(-10, 10), 3)
        ])
    return coords

def generate_fake_interactions():
    """生成模拟相互作用"""
    interactions = []
    num_interactions = random.randint(3, 8)
    
    residues = ["ASP123", "SER456", "PHE234", "ARG789", "TYR345", "LEU567"]
    interaction_types = ["hydrogen_bond", "hydrophobic", "pi_stacking", "salt_bridge"]
    
    for _ in range(num_interactions):
        interactions.append({
            "type": random.choice(interaction_types),
            "residue": random.choice(residues),
            "distance": round(random.uniform(1.8, 4.5), 2),
            "strength": random.choice(["strong", "medium", "weak"])
        })
    
    return interactions

if __name__ == '__main__':
    print("Starting Fake API Server...")
    print("Available endpoints:")
    print("- POST /api/compounds/search")
    print("- POST /api/compounds/generate") 
    print("- GET /api/targets/list")
    print("- POST /api/docking/submit")
    print("- POST /api/admet/predict")
    print("- POST /api/synthesis/analyze")
    print("- POST /api/workflow/run")
    
    app.run(host='0.0.0.0', port=5000, debug=True)

