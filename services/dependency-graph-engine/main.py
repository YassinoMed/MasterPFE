import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import RedirectResponse
from graph import DependencyGraph

app = FastAPI(title="Dependency Graph Engine")

# Initialize Graph
try:
    dep_graph = DependencyGraph()
except Exception as e:
    print(f"Failed to load graph: {e}")
    dep_graph = None

# Mount static files for the frontend
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/")
def read_root():
    return RedirectResponse(url="/static/index.html")

@app.get("/api/dependencies")
def get_dependencies():
    if not dep_graph:
        raise HTTPException(status_code=500, detail="Graph not initialized")
    return dep_graph.get_full_graph()

@app.get("/api/blast-radius/{node_id}")
def get_blast_radius(node_id: str):
    if not dep_graph:
        raise HTTPException(status_code=500, detail="Graph not initialized")
    affected = dep_graph.get_blast_radius(node_id)
    return {"node": node_id, "blast_radius": affected}

@app.get("/api/impact-analysis/{node_id}")
def get_impact_analysis(node_id: str):
    if not dep_graph:
        raise HTTPException(status_code=500, detail="Graph not initialized")
    dependencies = dep_graph.get_impact_analysis(node_id)
    return {"node": node_id, "impact_analysis": dependencies}

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8080)
