"""Refresh rr-42 proof closure without changing historical rr-38 evidence."""
from rr42_density import CASE, PROOF_CASE
from rr38_proof_case import build

if __name__=='__main__': build(case=CASE,output=PROOF_CASE)
