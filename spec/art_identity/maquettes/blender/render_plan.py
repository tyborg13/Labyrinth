"""Opt-in bounded pass selection; historical render calls keep their plan."""


def plan(view, *, ownership_only=False, silhouettes_only=False, fit_only=False,
         preview=False, solo_parts=None, solos_only=False, image_modes=None, facing=True):
    if solos_only and (preview or fit_only or silhouettes_only or not ownership_only or solo_parts is None):
        raise ValueError('Solos-only capture needs an explicit ownership batch')
    if image_modes is not None:
        modes=tuple(image_modes)
        if not preview or fit_only or solos_only or not modes or len(set(modes))!=len(modes) or not set(modes)<={'parts','clay','silhouette'}:
            raise ValueError('Explicit image modes require a distinct preview subset')
    else:
        modes=('parts',) if ownership_only else ('silhouette',) if silhouettes_only else ('parts','clay','silhouette')
    return {'facing':view=='front' and facing and not solos_only,
            'image_modes':() if solos_only else modes,
            'final_silhouette':not solos_only}
