"""Refresh proof assets from the exact current production partitions."""
from rr44_case import CASE
from rr38_proof_case import build

if __name__=='__main__':build(case=CASE,output=CASE/'proof/production_case')
