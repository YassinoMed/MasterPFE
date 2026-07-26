import math
import logging

logging.basicConfig(level=logging.INFO, format="%(asctime)s - R_WORKLOAD - %(message)s")

class RiskWorkloadCalculator:
    """
    Calculates the dynamic risk score (R_workload) for a given AI workload
    based on empirical calibration of various security metrics over time.
    """
    
    def __init__(self):
        # Coefficients empirically derived from incident history
        self.w_sast = 0.15      # Weight of static vulnerabilities
        self.w_runtime = 0.40   # Weight of runtime anomalies (e.g. Falco alerts)
        self.w_ai_sec = 0.45    # Weight of AI-Sec rejections (prompt injections)
        self.decay_factor = 0.9 # Exponential decay for older incidents
        
    def calculate_score(self, sast_vulns: int, runtime_alerts: list, ai_rejections: list, days_since_incident: int) -> float:
        """
        Calculates the risk score based on current metrics.
        """
        logging.info(f"Calculating R_workload (SAST: {sast_vulns}, Runtime Alerts: {len(runtime_alerts)}, AI Rejections: {len(ai_rejections)})")
        
        # Base risk from static analysis (capped)
        sast_score = min(sast_vulns * 5.0, 100.0) * self.w_sast
        
        # Runtime risk calculated with exponential decay based on recency
        time_penalty = math.pow(self.decay_factor, days_since_incident)
        runtime_score = min(len(runtime_alerts) * 15.0, 100.0) * self.w_runtime * time_penalty
        
        # AI risk is critical and penalizes heavily
        ai_score = min(len(ai_rejections) * 25.0, 100.0) * self.w_ai_sec * time_penalty
        
        total_risk = sast_score + runtime_score + ai_score
        normalized_risk = min(total_risk, 100.0)
        
        logging.info(f"Final Score: {normalized_risk:.2f}/100.0 (SAST={sast_score:.2f}, RUNTIME={runtime_score:.2f}, AI={ai_score:.2f})")
        return normalized_risk

if __name__ == "__main__":
    calc = RiskWorkloadCalculator()
    
    # Scenario 1: Clean workload, old minor incident
    print("--- Scenario 1: Clean Workload ---")
    score1 = calc.calculate_score(sast_vulns=1, runtime_alerts=["File write"], ai_rejections=[], days_since_incident=14)
    print(f"R_workload = {score1:.2f}\n")
    
    # Scenario 2: Under attack
    print("--- Scenario 2: Active Attack ---")
    score2 = calc.calculate_score(sast_vulns=2, runtime_alerts=["Execve call", "Network out"], ai_rejections=["Jailbreak attempt", "Data exfiltration"], days_since_incident=0)
    print(f"R_workload = {score2:.2f}\n")
