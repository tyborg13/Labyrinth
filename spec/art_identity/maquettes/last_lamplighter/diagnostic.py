"""Hash-bound delivery verification; historical entry point retained for tooling."""
from spec.art_identity.maquettes.blender.delivery_validation import seal_delivery,validate_delivery


def native_contract(spec,native):
    from .acceptance import native_pose_contract
    return native_pose_contract(spec,native)


def seal(spec,folder):
    seal_delivery(spec,folder)
    return validate_delivery(spec,folder)


def verify(spec,folder):
    from .acceptance import validate_acceptance
    binding=validate_delivery(spec,folder);validate_acceptance(folder,spec)
    print('MQ18_HASH_BOUND_DELIVERY: PASS',flush=True)
    return binding
