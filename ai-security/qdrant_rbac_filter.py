import json
import logging
from typing import List, Dict

logging.basicConfig(level=logging.INFO, format="%(asctime)s - QDRANT-RBAC - %(message)s")

class VectorRBACFilter:
    """
    Demonstrates Cryptographic Vector Isolation (RBAC) in Qdrant.
    It builds a filter payload that guarantees the user only retrieves vectors
    they are authorized to see based on their roles.
    """
    
    def __init__(self, collection_name: str):
        self.collection_name = collection_name
        
    def build_search_query(self, query_vector: List[float], user_roles: List[str], top_k: int = 5) -> Dict:
        """
        Builds the Qdrant search payload with an enforced must-have condition on allowed_roles.
        """
        logging.info(f"Building RBAC search query for user with roles: {user_roles}")
        
        # Enforce that the document's allowed_roles must intersect with the user's roles
        rbac_filter = {
            "must": [
                {
                    "key": "allowed_roles",
                    "match": {
                        "any": user_roles
                    }
                }
            ]
        }
        
        payload = {
            "collection_name": self.collection_name,
            "vector": query_vector,
            "limit": top_k,
            "filter": rbac_filter,
            "with_payload": True
        }
        
        return payload

if __name__ == "__main__":
    rbac = VectorRBACFilter(collection_name="secure_knowledge_base")
    
    # User with standard employee role
    standard_user_roles = ["ROLE_EMPLOYEE"]
    query1 = rbac.build_search_query([0.1, 0.2, 0.3], standard_user_roles)
    print("--- Standard User Query ---")
    print(json.dumps(query1, indent=2))
    
    # User with executive role
    executive_user_roles = ["ROLE_EMPLOYEE", "ROLE_EXECUTIVE", "ROLE_FINANCE"]
    query2 = rbac.build_search_query([0.1, 0.2, 0.3], executive_user_roles)
    print("\n--- Executive User Query ---")
    print(json.dumps(query2, indent=2))
