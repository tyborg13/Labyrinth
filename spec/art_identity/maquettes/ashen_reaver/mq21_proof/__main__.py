"""Stable mq21_proof CLI; native measurement imports remain lightweight."""
from .workflow import main

try:
    main()
except (ValueError,OSError,KeyError,TimeoutError) as error:
    print("MQ21_PROOF_ERROR: "+str(error))
    raise SystemExit(2)
