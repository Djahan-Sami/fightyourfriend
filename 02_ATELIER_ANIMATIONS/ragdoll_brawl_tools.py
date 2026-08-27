"""Atelier Blender minimal de Ragdoll Brawl.

Principes :
- la garde et les coups sont deux actions totalement separees ;
- aucun coup n'existe tant que l'utilisateur ne le cree pas ;
- chaque bouton d'export ne peut exporter que ce qui est affiche ;
- un coup reste inactif tant que son animation n'a pas ete exportee.
"""

bl_info = {
    "name": "Ragdoll Brawl - Atelier simple",
    "author": "Ragdoll Brawl",
    "version": (2, 0, 0),
    "blender": (5, 0, 0),
    "location": "Vue 3D > panneau Ragdoll Brawl",
    "category": "Animation",
}

import json
import hashlib
import math
import os
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector


MOVES = [
    ("jab", "Jab", "Poing neutre"),
    ("hook", "Crochet tete", "Poing + avant"),
    ("body_hook", "Crochet au corps", "Poing + bas"),
    ("uppercut", "Uppercut", "Poing + haut"),
    ("spinning_backfist", "Poing retourne", "Poing + arriere"),
    ("middle_kick", "Middle kick", "Pied neutre"),
    ("front_kick", "Chasse", "Pied + avant"),
    ("spinning_kick", "Coup de pied retourne", "Pied + arriere"),
    ("high_kick", "High kick", "Pied + haut"),
    ("sweep", "Balayage", "Pied + bas"),
    ("air_punch", "Air : poing neutre", "En l'air"),
    ("air_cross", "Air : poing avant", "En l'air"),
    ("air_backfist", "Air : poing arriere", "En l'air"),
    ("air_upper", "Air : poing haut", "En l'air"),
    ("air_hammer", "Air : poing bas", "En l'air"),
    ("air_kick", "Air : pied neutre", "En l'air"),
    ("air_side_kick", "Air : pied avant", "En l'air"),
    ("air_roundhouse", "Air : pied arriere", "En l'air"),
    ("air_rising_kick", "Air : pied haut", "En l'air"),
    ("dive_kick", "Air : pied bas", "En l'air"),
]

MOVE_LABELS = {identifier: label for identifier, label, _description in MOVES}

DEFAULT_SLOTS = {
    "ground/punch/neutral": "jab",
    "ground/punch/forward": "hook",
    "ground/punch/back": "spinning_backfist",
    "ground/punch/up": "uppercut",
    "ground/punch/down": "body_hook",
    "ground/kick/neutral": "middle_kick",
    "ground/kick/forward": "front_kick",
    "ground/kick/back": "spinning_kick",
    "ground/kick/up": "high_kick",
    "ground/kick/down": "sweep",
    "air/punch/neutral": "air_punch",
    "air/punch/forward": "air_cross",
    "air/punch/back": "air_backfist",
    "air/punch/up": "air_upper",
    "air/punch/down": "air_hammer",
    "air/kick/neutral": "air_kick",
    "air/kick/forward": "air_side_kick",
    "air/kick/back": "air_roundhouse",
    "air/kick/up": "air_rising_kick",
    "air/kick/down": "dive_kick",
}
MOVE_SLOTS = {move: slot for slot, move in DEFAULT_SLOTS.items()}

# preparation, impact, retour, degats
DEFAULTS = {
    "jab": (3, 3, 6, 6),
    "hook": (9, 4, 12, 11),
    "body_hook": (10, 4, 13, 11),
    "uppercut": (5, 4, 14, 14),
    "spinning_backfist": (8, 4, 14, 14),
    "middle_kick": (6, 4, 13, 13),
    "front_kick": (6, 4, 12, 11),
    "spinning_kick": (14, 5, 16, 17),
    "high_kick": (7, 4, 15, 15),
    "sweep": (7, 5, 16, 10),
}

DIRECT_ELBOWS = {
    "COUDE_3D_ROUGE": ("COUDE_ROUGE", "LeftArm", "LeftForeArm"),
    "COUDE_3D_BLEU": ("COUDE_BLEU", "RightArm", "RightForeArm"),
}
DIRECT_HANDS = {
    "COUDE_3D_ROUGE": "MAIN_ROUGE",
    "COUDE_3D_BLEU": "MAIN_BLEUE",
}
DIRECT_KNEES = {
    "GENOU_3D_ROUGE": ("GENOU_ROUGE", "LeftUpLeg", "LeftLeg"),
    "GENOU_3D_BLEU": ("GENOU_BLEU", "RightUpLeg", "RightLeg"),
}
DIRECT_FEET = {
    "GENOU_3D_ROUGE": "PIED_ROUGE",
    "GENOU_3D_BLEU": "PIED_BLEU",
}

CONTROL_NAMES = [
    "MAIN_ROUGE", "MAIN_BLEUE", "COUDE_3D_ROUGE", "COUDE_3D_BLEU",
    "PIED_ROUGE", "PIED_BLEU", "GENOU_3D_ROUGE", "GENOU_3D_BLEU",
    "BASSIN", "TORSE", "TETE", "CORPS_ENTIER",
]

POSE_LABELS = {
    "preparation": "PREPARATION",
    "impact": "IMPACT",
    "return": "RETOUR",
}

EXISTING_ITEMS = []
SOURCE_FORWARD = -1.0
CANONICAL_RIG_ID = "ragdoll_brawl_humanoid_v1"
CANONICAL_RIG_VERSION = 1


def rig():
    return bpy.data.objects.get("RB_Rig")


def neutral_action():
    return bpy.data.actions.get("NEUTRE") or bpy.data.actions.get("NEUTRE_VULNERABLE")


def guard_action():
    return bpy.data.actions.get("GARDE")


def crouch_action(create=False):
    action = bpy.data.actions.get("ACCROUPI")
    if action or not create:
        return action
    neutral = neutral_action()
    if not neutral:
        return None
    # Copie independante : modifier l'accroupissement ne peut changer aucune
    # autre position ni aucun coup deja cree.
    action = neutral.copy()
    action.name = "ACCROUPI"
    action.pop("rb_neutral_authored_v2", None)
    action["rb_crouch_action_v1"] = True
    return action


def user_actions():
    return [action for action in bpy.data.actions if bool(action.get("rb_user_move_v2", False))]


def controls(armature):
    return [armature.pose.bones[name] for name in CONTROL_NAMES if name in armature.pose.bones]


def deform_skeleton_signature(armature):
    """Identite stable du squelette exporte, independante des poses."""
    bones = []
    for bone in sorted((item for item in armature.data.bones if item.use_deform), key=lambda item: item.name):
        matrix = [round(value, 6) for row in bone.matrix_local for value in row]
        bones.append([bone.name, bone.parent.name if bone.parent else "", matrix])
    payload = json.dumps(bones, separators=(",", ":"), ensure_ascii=True)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def validate_canonical_rig(armature):
    if armature.get("rb_canonical_rig_id") != CANONICAL_RIG_ID:
        return False, "Ce fichier n'utilise pas le squelette commun du jeu"
    expected = str(armature.get("rb_canonical_signature", ""))
    if not expected or deform_skeleton_signature(armature) != expected:
        return False, "Le squelette a ete modifie en mode Edition. Recharge le fichier propre"
    return True, ""


def create_skeleton_carrier(armature):
    """Triangle technique minuscule qui force glTF a conserver un Skeleton."""
    mesh = bpy.data.meshes.new("RB_SkeletonCarrier_Mesh")
    mesh.from_pydata(
        [(0.0, 0.0, 0.0), (0.001, 0.0, 0.0), (0.0, 0.001, 0.0)],
        [],
        [(0, 1, 2)],
    )
    carrier = bpy.data.objects.new("RB_SkeletonCarrier", mesh)
    bpy.context.scene.collection.objects.link(carrier)
    group = carrier.vertex_groups.new(name="BASSIN")
    group.add([0, 1, 2], 1.0, "REPLACE")
    modifier = carrier.modifiers.new(name="Squelette commun", type="ARMATURE")
    modifier.object = armature
    return carrier


def output_dir():
    appdata = os.environ.get("APPDATA", str(Path.home() / "AppData/Roaming"))
    directory = Path(appdata) / "Godot" / "app_userdata" / "Ragdoll Brawl" / "attacks"
    directory.mkdir(parents=True, exist_ok=True)
    return directory


def save_blend():
    if bpy.data.filepath:
        bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)


def capture_pose(armature):
    return {
        bone.name: (bone.location.copy(), bone.rotation_quaternion.copy(), bone.scale.copy())
        for bone in controls(armature)
    }


def apply_pose(armature, pose):
    for name, transforms in pose.items():
        bone = armature.pose.bones.get(name)
        if bone:
            bone.location = transforms[0]
            bone.rotation_mode = "QUATERNION"
            bone.rotation_quaternion = transforms[1]
            bone.scale = transforms[2]


def key_pose(armature, frame):
    for bone in controls(armature):
        bone.rotation_mode = "QUATERNION"
        bone.keyframe_insert("location", frame=frame, group=bone.name)
        bone.keyframe_insert("rotation_quaternion", frame=frame, group=bone.name)
        bone.keyframe_insert("scale", frame=frame, group=bone.name)


def set_linear(action):
    for layer in action.layers:
        for strip in layer.strips:
            for channelbag in strip.channelbags:
                for fcurve in channelbag.fcurves:
                    for point in fcurve.keyframe_points:
                        point.interpolation = "LINEAR"


def read_pose(context, action, frame):
    armature = rig()
    previous_action = armature.animation_data.action if armature.animation_data else None
    previous_frame = context.scene.frame_current
    previous_pose = capture_pose(armature)
    armature.animation_data_create()
    armature.animation_data.action = action
    context.scene.frame_set(frame)
    context.view_layer.update()
    pose = capture_pose(armature)
    armature.animation_data.action = previous_action
    context.scene.frame_set(previous_frame)
    context.view_layer.update()
    apply_pose(armature, previous_pose)
    return pose


def guard_pose(context):
    return read_pose(context, guard_action(), 1)


def frames_from_values(startup, active, recovery):
    return {
        "guard": 1,
        # La preparation est une vraie pose intermediaire. Auparavant elle se
        # trouvait une seule image avant l'impact : tout changement restant
        # (bassin, bras, jambes...) sautait donc instantanement a l'impact.
        "preparation": max(2, 1 + startup // 2),
        "impact": startup + 1,
        "return": startup + active + recovery + 1,
    }


def scene_frames(scene):
    return frames_from_values(scene.rb2_startup, scene.rb2_active, scene.rb2_recovery)


def action_frames(action):
    return {
        "guard": 1,
        "preparation": int(action.get("rb_preparation_frame", 2)),
        "impact": int(action.get("rb_impact_frame", 3)),
        "return": int(action.get("rb_return_frame", 13)),
    }


def store_settings(scene, action):
    frames = scene_frames(scene)
    action["rb_startup"] = scene.rb2_startup
    action["rb_active"] = scene.rb2_active
    action["rb_recovery"] = scene.rb2_recovery
    action["rb_preparation_frame"] = frames["preparation"]
    action["rb_impact_frame"] = frames["impact"]
    action["rb_return_frame"] = frames["return"]
    action["rb_keep_end_position"] = bool(scene.rb2_keep_end_position)


def load_settings(scene, action):
    defaults = DEFAULTS.get(action.name, (6, 4, 10, 8))
    scene.rb2_startup = int(action.get("rb_startup", defaults[0]))
    scene.rb2_active = int(action.get("rb_active", defaults[1]))
    scene.rb2_recovery = int(action.get("rb_recovery", defaults[2]))
    scene.rb2_keep_end_position = bool(action.get("rb_keep_end_position", False))
    scene.frame_start = 1
    scene.frame_end = action_frames(action)["return"]


def root_motion_curve(action):
    """Deplacement horizontal du bassin, en proportion de la taille du corps."""
    armature = rig()
    if not armature or "BASSIN" not in armature.pose.bones:
        return []
    head = armature.data.bones.get("TETE")
    hips = armature.data.bones.get("BASSIN")
    if not head or not hips:
        return []
    source_height = (head.matrix_local.translation - hips.matrix_local.translation).length
    if source_height <= 0.0001:
        return []

    previous_action = armature.animation_data.action if armature.animation_data else None
    previous_frame = bpy.context.scene.frame_current
    armature.animation_data_create()
    armature.animation_data.action = action
    frames = action_frames(action)
    ordered = [frames[name] for name in ("guard", "preparation", "impact", "return")]
    start_frame = float(frames["guard"])
    duration = max(float(frames["return"] - frames["guard"]), 1.0)
    samples = []
    origin_x = 0.0
    try:
        for index, frame in enumerate(ordered):
            bpy.context.scene.frame_set(frame)
            bpy.context.view_layer.update()
            x = float(armature.pose.bones["BASSIN"].matrix.translation.x)
            if index == 0:
                origin_x = x
            progress = (float(frame) - start_frame) / duration
            displacement = max(-1.5, min(1.5, (x - origin_x) / source_height))
            samples.append([round(progress, 6), round(displacement, 6)])
    finally:
        armature.animation_data.action = previous_action
        bpy.context.scene.frame_set(previous_frame)
        bpy.context.view_layer.update()
    return samples


def existing_move_items(_self, _context):
    global EXISTING_ITEMS
    names = {action.name for action in user_actions()}
    EXISTING_ITEMS = [
        (identifier, label, description, index)
        for index, (identifier, label, description) in enumerate(MOVES)
        if identifier in names
    ]
    if not EXISTING_ITEMS:
        EXISTING_ITEMS = [("__none__", "Aucun coup cree", "Cree ton premier coup", 0)]
    return EXISTING_ITEMS


def manifest_data():
    path = output_dir() / "attack_manifest.json"
    if path.exists():
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(value, dict):
                value.setdefault("version", 2)
                value.setdefault("slots", dict(DEFAULT_SLOTS))
                value.setdefault("moves", {})
                value.setdefault("guard", {})
                value.setdefault("neutral", {})
                value.setdefault("crouch", {})
                value.setdefault("hurtboxes", {
                    "neutral": {}, "guard": {}, "crouch": {}, "moves": {},
                })
                value["version"] = 3
                value["rig"] = {"id": CANONICAL_RIG_ID, "version": CANONICAL_RIG_VERSION}
                return value
        except Exception:
            pass
    return {
        "version": 3,
        "rig": {"id": CANONICAL_RIG_ID, "version": CANONICAL_RIG_VERSION},
        "slots": dict(DEFAULT_SLOTS),
        "moves": {},
        "guard": {},
        "neutral": {},
        "crouch": {},
        "hurtboxes": {"neutral": {}, "guard": {}, "crouch": {}, "moves": {}},
    }


def write_manifest(data):
    path = output_dir() / "attack_manifest.json"
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    temporary.replace(path)


def export_active_action(filepath, action, frame_end):
    armature = rig()
    valid, message = validate_canonical_rig(armature)
    if not valid:
        raise RuntimeError(message)
    armature.animation_data_create()
    armature.animation_data.action = action
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = frame_end
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    # Les formes colorees sont seulement des poignees d'animation. Blender les
    # suivrait comme dependances de l'armature si elles restaient branchees.
    # On les retire le temps de l'export afin que le GLB ne contienne que le
    # squelette deformant et l'Action active, puis on les remet immediatement.
    custom_shapes = {bone.name: bone.custom_shape for bone in armature.pose.bones}
    shape_objects = {shape for shape in custom_shapes.values() if shape is not None}
    shape_links = {shape: list(shape.users_collection) for shape in shape_objects}
    carrier = None
    try:
        for bone in armature.pose.bones:
            bone.custom_shape = None
        for shape, collections in shape_links.items():
            for collection in collections:
                collection.objects.unlink(shape)
        bpy.context.view_layer.update()
        carrier = create_skeleton_carrier(armature)
        carrier.select_set(True)
        bpy.ops.export_scene.gltf(
            filepath=str(filepath),
            export_format="GLB",
            use_selection=True,
            export_animations=True,
            export_animation_mode="ACTIVE_ACTIONS",
            export_force_sampling=True,
            export_def_bones=True,
            export_skins=True,
            export_materials="NONE",
            export_cameras=False,
            export_lights=False,
            export_extras=True,
            export_anim_slide_to_zero=True,
        )
    finally:
        if carrier is not None:
            mesh = carrier.data
            bpy.data.objects.remove(carrier, do_unlink=True)
            bpy.data.meshes.remove(mesh)
        for shape, collections in shape_links.items():
            for collection in collections:
                if shape.name not in collection.objects:
                    collection.objects.link(shape)
        for name, shape in custom_shapes.items():
            if name in armature.pose.bones:
                armature.pose.bones[name].custom_shape = shape
    bpy.ops.object.mode_set(mode="POSE")


def show_controls(armature):
    for collection in armature.data.collections:
        collection.is_visible = collection.name == "01_CONTROLES_A_ANIMER"


def lock_and_hide_shoulders(armature):
    """Retire l'ancien controle d'epaule et garantit une epaule fixe."""
    shoulder_names = ("LeftShoulder", "RightShoulder")
    shoulder_paths = tuple(f'pose.bones["{name}"]' for name in shoulder_names)

    # Les anciennes versions ont pu ajouter des cles sur les epaules. Elles ne
    # doivent plus influencer une pose : seul le guide du coude pilote le bras.
    for action in bpy.data.actions:
        for layer in action.layers:
            for strip in layer.strips:
                for channelbag in strip.channelbags:
                    for fcurve in list(channelbag.fcurves):
                        if fcurve.data_path.startswith(shoulder_paths):
                            channelbag.fcurves.remove(fcurve)

    controls_collection = armature.data.collections.get("01_CONTROLES_A_ANIMER")
    technical_collection = armature.data.collections.get("02_OS_TECHNIQUES_CACHES")
    for name in shoulder_names:
        pose_bone = armature.pose.bones.get(name)
        data_bone = armature.data.bones.get(name)
        if pose_bone:
            pose_bone.location = Vector((0.0, 0.0, 0.0))
            pose_bone.rotation_mode = "QUATERNION"
            pose_bone.rotation_quaternion = Quaternion()
            pose_bone.scale = Vector((1.0, 1.0, 1.0))
            pose_bone.custom_shape = None
        if data_bone and controls_collection and controls_collection.name in data_bone.collections:
            controls_collection.unassign(data_bone)
        if data_bone and technical_collection and technical_collection.name not in data_bone.collections:
            technical_collection.assign(data_bone)


def keyed_frames(action):
    frames = set()
    for layer in action.layers:
        for strip in layer.strips:
            for channelbag in strip.channelbags:
                for fcurve in channelbag.fcurves:
                    frames.update(point.co.x for point in fcurve.keyframe_points)
    return sorted(frames or {1.0})


def align_ik_pole_to_handle(armature, constraint, lower_name, handle_name):
    """Calibre l'angle interne de Blender pour que poignee et coude coincident."""
    target = armature.pose.bones[handle_name].matrix.translation.copy()
    best_angle = constraint.pole_angle
    best_error = float("inf")

    for index in range(72):
        angle = -math.pi + index * (2.0 * math.pi / 72.0)
        constraint.pole_angle = angle
        bpy.context.view_layer.update()
        evaluated = armature.evaluated_get(bpy.context.evaluated_depsgraph_get())
        error = (evaluated.pose.bones[lower_name].head - target).length
        if error < best_error:
            best_error = error
            best_angle = angle

    coarse_step = 2.0 * math.pi / 72.0
    for index in range(41):
        angle = best_angle - coarse_step + index * (2.0 * coarse_step / 40.0)
        constraint.pole_angle = angle
        bpy.context.view_layer.update()
        evaluated = armature.evaluated_get(bpy.context.evaluated_depsgraph_get())
        error = (evaluated.pose.bones[lower_name].head - target).length
        if error < best_error:
            best_error = error
            best_angle = angle

    constraint.pole_angle = best_angle
    bpy.context.view_layer.update()


def ensure_direct_elbow_controls(armature):
    """Cree une vraie poignee placee sur chaque coude et preserve les poses."""
    missing = [name for name in DIRECT_ELBOWS if name not in armature.pose.bones]
    actions = []
    seen = set()
    for action in (neutral_action(), guard_action(), crouch_action(), *user_actions()):
        if action and action.name not in seen:
            actions.append(action)
            seen.add(action.name)

    previous_action = armature.animation_data.action if armature.animation_data else None
    previous_frame = bpy.context.scene.frame_current
    samples = {}

    if missing:
        # On memorise les coudes produits par l'ancien rig avant de remplacer
        # les cibles. Les poses creees par l'utilisateur restent donc identiques.
        for action in actions:
            armature.animation_data.action = action
            for frame in keyed_frames(action):
                bpy.context.scene.frame_set(int(round(frame)))
                bpy.context.view_layer.update()
                evaluated = armature.evaluated_get(bpy.context.evaluated_depsgraph_get())
                samples[(action.name, frame)] = {
                    direct_name: evaluated.pose.bones[lower_name].head.copy()
                    for direct_name, (_legacy, _upper, lower_name) in DIRECT_ELBOWS.items()
                }

        bpy.context.view_layer.objects.active = armature
        armature.select_set(True)
        if armature.mode != "OBJECT":
            bpy.ops.object.mode_set(mode="OBJECT")
        bpy.ops.object.mode_set(mode="EDIT")
        for direct_name in missing:
            _legacy, _upper, lower_name = DIRECT_ELBOWS[direct_name]
            joint = armature.data.edit_bones[lower_name].head.copy()
            edit_bone = armature.data.edit_bones.new(direct_name)
            edit_bone.head = joint
            edit_bone.tail = joint + Vector((0.0, 0.0, 0.22))
            edit_bone.parent = armature.data.edit_bones.get("CORPS_ENTIER")
            edit_bone.use_deform = False
        bpy.ops.object.mode_set(mode="POSE")

    controls_collection = armature.data.collections.get("01_CONTROLES_A_ANIMER")
    technical_collection = armature.data.collections.get("02_OS_TECHNIQUES_CACHES")

    for direct_name, (legacy_name, _upper_name, lower_name) in DIRECT_ELBOWS.items():
        direct_pose = armature.pose.bones.get(direct_name)
        direct_data = armature.data.bones.get(direct_name)
        legacy_pose = armature.pose.bones.get(legacy_name)
        legacy_data = armature.data.bones.get(legacy_name)
        if not direct_pose or not direct_data:
            continue

        if controls_collection and controls_collection.name not in direct_data.collections:
            controls_collection.assign(direct_data)
        if technical_collection and technical_collection.name in direct_data.collections:
            technical_collection.unassign(direct_data)
        direct_pose.custom_shape = legacy_pose.custom_shape if legacy_pose else None
        direct_pose.use_custom_shape_bone_size = False
        if legacy_pose:
            direct_pose.custom_shape_scale_xyz = legacy_pose.custom_shape_scale_xyz
            direct_pose.color.palette = legacy_pose.color.palette
            direct_pose.color.custom.normal = legacy_pose.color.custom.normal
            direct_pose.color.custom.select = legacy_pose.color.custom.select
            direct_pose.color.custom.active = legacy_pose.color.custom.active
        direct_pose.rotation_mode = "QUATERNION"

        # L'ancien guide etait loin devant le bras. La nouvelle cible se trouve
        # vraiment sur le coude et peut etre deplacee librement dans les 3 axes.
        if not bool(armature.get("rb_free_rotating_shoulders_v2", False)):
            for constraint in armature.pose.bones[lower_name].constraints:
                if constraint.type == "IK" and constraint.chain_count == 2:
                    constraint.pole_target = armature
                    constraint.pole_subtarget = direct_name

        if legacy_pose:
            legacy_pose.custom_shape = None
        if legacy_data and controls_collection and controls_collection.name in legacy_data.collections:
            controls_collection.unassign(legacy_data)
        if legacy_data and technical_collection and technical_collection.name not in legacy_data.collections:
            technical_collection.assign(legacy_data)

    if missing:
        reference_action = guard_action() or (actions[0] if actions else None)
        if reference_action:
            reference_frame = keyed_frames(reference_action)[0]
            armature.animation_data.action = reference_action
            bpy.context.scene.frame_set(int(round(reference_frame)))
            for direct_name, position in samples[(reference_action.name, reference_frame)].items():
                pose_bone = armature.pose.bones[direct_name]
                matrix = pose_bone.matrix.copy()
                matrix.translation = position
                pose_bone.matrix = matrix
            bpy.context.view_layer.update()
            for direct_name, (_legacy_name, _upper_name, lower_name) in DIRECT_ELBOWS.items():
                constraint = next(
                    (item for item in armature.pose.bones[lower_name].constraints
                     if item.type == "IK" and item.chain_count == 2),
                    None,
                )
                if constraint:
                    align_ik_pole_to_handle(armature, constraint, lower_name, direct_name)

        for action in actions:
            armature.animation_data.action = action
            for frame in keyed_frames(action):
                bpy.context.scene.frame_set(int(round(frame)))
                for direct_name, position in samples[(action.name, frame)].items():
                    pose_bone = armature.pose.bones[direct_name]
                    matrix = pose_bone.matrix.copy()
                    matrix.translation = position
                    pose_bone.matrix = matrix
                    pose_bone.rotation_mode = "QUATERNION"
                    pose_bone.keyframe_insert("location", frame=frame, group=direct_name)
                    pose_bone.keyframe_insert("rotation_quaternion", frame=frame, group=direct_name)
                    pose_bone.keyframe_insert("scale", frame=frame, group=direct_name)

        legacy_paths = tuple(f'pose.bones["{value[0]}"]' for value in DIRECT_ELBOWS.values())
        for action in actions:
            for layer in action.layers:
                for strip in layer.strips:
                    for channelbag in strip.channelbags:
                        for fcurve in list(channelbag.fcurves):
                            if fcurve.data_path.startswith(legacy_paths):
                                channelbag.fcurves.remove(fcurve)

    armature["rb_direct_elbows_v1"] = True
    armature.animation_data.action = previous_action
    bpy.context.scene.frame_set(previous_frame)
    bpy.context.view_layer.update()


def configure_free_arm_constraints(armature):
    """Le coude oriente le bras ; la main oriente seulement l'avant-bras."""
    for direct_name, (_legacy_name, upper_name, lower_name) in DIRECT_ELBOWS.items():
        hand_name = DIRECT_HANDS[direct_name]
        upper_pose = armature.pose.bones[upper_name]
        lower_pose = armature.pose.bones[lower_name]

        for pose_bone in (upper_pose, lower_pose):
            for constraint in list(pose_bone.constraints):
                if constraint.type == "IK":
                    pose_bone.constraints.remove(constraint)

        shoulder_ik = upper_pose.constraints.new("IK")
        shoulder_ik.name = "Coude 3D - rotation epaule"
        shoulder_ik.target = armature
        shoulder_ik.subtarget = direct_name
        shoulder_ik.chain_count = 1
        shoulder_ik.use_stretch = False

        forearm_ik = lower_pose.constraints.new("IK")
        forearm_ik.name = "Main - rotation avant-bras"
        forearm_ik.target = armature
        forearm_ik.subtarget = hand_name
        forearm_ik.chain_count = 1
        forearm_ik.use_stretch = False


def ensure_free_rotating_shoulders(armature):
    """Libere les trois rotations de l'epaule sans deplacer son articulation."""
    needs_upgrade = not bool(armature.get("rb_free_rotating_shoulders_v2", False))
    actions = []
    seen = set()
    for action in (neutral_action(), guard_action(), crouch_action(), *user_actions()):
        if action and action.name not in seen:
            actions.append(action)
            seen.add(action.name)

    previous_action = armature.animation_data.action if armature.animation_data else None
    previous_frame = bpy.context.scene.frame_current
    samples = {}

    if needs_upgrade:
        # Capture le resultat visuel actuel avant de changer la hierarchie.
        for action in actions:
            armature.animation_data.action = action
            for frame in keyed_frames(action):
                bpy.context.scene.frame_set(int(round(frame)))
                bpy.context.view_layer.update()
                evaluated = armature.evaluated_get(bpy.context.evaluated_depsgraph_get())
                samples[(action.name, frame)] = {
                    direct_name: (
                        evaluated.pose.bones[lower_name].head.copy(),
                        armature.pose.bones[DIRECT_HANDS[direct_name]].matrix.copy(),
                    )
                    for direct_name, (_legacy, _upper, lower_name) in DIRECT_ELBOWS.items()
                }

        # La main devient enfant du coude : elle suit le bras lorsque le coude
        # bouge, puis elle reste reglable separement pour plier l'avant-bras.
        bpy.context.view_layer.objects.active = armature
        armature.select_set(True)
        if armature.mode != "OBJECT":
            bpy.ops.object.mode_set(mode="OBJECT")
        bpy.ops.object.mode_set(mode="EDIT")
        for direct_name, hand_name in DIRECT_HANDS.items():
            hand_bone = armature.data.edit_bones.get(hand_name)
            elbow_bone = armature.data.edit_bones.get(direct_name)
            if hand_bone and elbow_bone:
                hand_bone.parent = elbow_bone
                hand_bone.use_connect = False
        bpy.ops.object.mode_set(mode="POSE")

    configure_free_arm_constraints(armature)

    if needs_upgrade:
        for action in actions:
            armature.animation_data.action = action
            for frame in keyed_frames(action):
                bpy.context.scene.frame_set(int(round(frame)))
                # Le coude d'abord, puis la matrice mondiale de la main afin de
                # neutraliser le changement de parent dans les anciennes poses.
                for direct_name, (elbow_position, _hand_matrix) in samples[(action.name, frame)].items():
                    elbow = armature.pose.bones[direct_name]
                    matrix = elbow.matrix.copy()
                    matrix.translation = elbow_position
                    elbow.matrix = matrix
                bpy.context.view_layer.update()
                for direct_name, (_elbow_position, hand_matrix) in samples[(action.name, frame)].items():
                    hand = armature.pose.bones[DIRECT_HANDS[direct_name]]
                    hand.matrix = hand_matrix
                bpy.context.view_layer.update()
                for direct_name in DIRECT_ELBOWS:
                    for pose_bone in (
                        armature.pose.bones[direct_name],
                        armature.pose.bones[DIRECT_HANDS[direct_name]],
                    ):
                        pose_bone.rotation_mode = "QUATERNION"
                        pose_bone.keyframe_insert("location", frame=frame, group=pose_bone.name)
                        pose_bone.keyframe_insert("rotation_quaternion", frame=frame, group=pose_bone.name)
                        pose_bone.keyframe_insert("scale", frame=frame, group=pose_bone.name)

        armature["rb_free_rotating_shoulders_v2"] = True

    armature.animation_data.action = previous_action
    bpy.context.scene.frame_set(previous_frame)
    bpy.context.view_layer.update()


def configure_free_leg_constraints(armature):
    """Le genou oriente la cuisse ; le pied oriente seulement le tibia."""
    for direct_name, (_legacy_name, upper_name, lower_name) in DIRECT_KNEES.items():
        foot_name = DIRECT_FEET[direct_name]
        upper_pose = armature.pose.bones[upper_name]
        lower_pose = armature.pose.bones[lower_name]

        for pose_bone in (upper_pose, lower_pose):
            for constraint in list(pose_bone.constraints):
                if constraint.type == "IK":
                    pose_bone.constraints.remove(constraint)

        hip_ik = upper_pose.constraints.new("IK")
        hip_ik.name = "Genou 3D - rotation hanche"
        hip_ik.target = armature
        hip_ik.subtarget = direct_name
        hip_ik.chain_count = 1
        hip_ik.use_stretch = False

        shin_ik = lower_pose.constraints.new("IK")
        shin_ik.name = "Pied - rotation tibia"
        shin_ik.target = armature
        shin_ik.subtarget = foot_name
        shin_ik.chain_count = 1
        shin_ik.use_stretch = False


def ensure_free_rotating_hips(armature):
    """Ajoute des genoux 3D : hanche fixe, cuisse libre en rotation."""
    missing = [name for name in DIRECT_KNEES if name not in armature.pose.bones]
    needs_upgrade = bool(missing) or not bool(armature.get("rb_free_rotating_hips_v1", False))
    actions = []
    seen = set()
    for action in (neutral_action(), guard_action(), crouch_action(), *user_actions()):
        if action and action.name not in seen:
            actions.append(action)
            seen.add(action.name)

    previous_action = armature.animation_data.action if armature.animation_data else None
    previous_frame = bpy.context.scene.frame_current
    samples = {}

    if needs_upgrade:
        # Memorise chaque genou et chaque controle de pied avant conversion.
        for action in actions:
            armature.animation_data.action = action
            for frame in keyed_frames(action):
                bpy.context.scene.frame_set(int(round(frame)))
                bpy.context.view_layer.update()
                evaluated = armature.evaluated_get(bpy.context.evaluated_depsgraph_get())
                samples[(action.name, frame)] = {
                    direct_name: (
                        evaluated.pose.bones[lower_name].head.copy(),
                        armature.pose.bones[DIRECT_FEET[direct_name]].matrix.copy(),
                    )
                    for direct_name, (_legacy, _upper, lower_name) in DIRECT_KNEES.items()
                }

        bpy.context.view_layer.objects.active = armature
        armature.select_set(True)
        if armature.mode != "OBJECT":
            bpy.ops.object.mode_set(mode="OBJECT")
        bpy.ops.object.mode_set(mode="EDIT")
        for direct_name in missing:
            _legacy, _upper, lower_name = DIRECT_KNEES[direct_name]
            joint = armature.data.edit_bones[lower_name].head.copy()
            edit_bone = armature.data.edit_bones.new(direct_name)
            edit_bone.head = joint
            edit_bone.tail = joint + Vector((0.0, 0.0, 0.22))
            edit_bone.parent = armature.data.edit_bones.get("CORPS_ENTIER")
            edit_bone.use_deform = False

        # Le pied suit le genou, puis reste libre pour regler le tibia.
        for direct_name, foot_name in DIRECT_FEET.items():
            foot_bone = armature.data.edit_bones.get(foot_name)
            knee_bone = armature.data.edit_bones.get(direct_name)
            if foot_bone and knee_bone:
                foot_bone.parent = knee_bone
                foot_bone.use_connect = False
        bpy.ops.object.mode_set(mode="POSE")

    controls_collection = armature.data.collections.get("01_CONTROLES_A_ANIMER")
    technical_collection = armature.data.collections.get("02_OS_TECHNIQUES_CACHES")
    for direct_name, (legacy_name, _upper_name, _lower_name) in DIRECT_KNEES.items():
        direct_pose = armature.pose.bones.get(direct_name)
        direct_data = armature.data.bones.get(direct_name)
        legacy_pose = armature.pose.bones.get(legacy_name)
        legacy_data = armature.data.bones.get(legacy_name)
        if not direct_pose or not direct_data:
            continue
        if controls_collection and controls_collection.name not in direct_data.collections:
            controls_collection.assign(direct_data)
        if technical_collection and technical_collection.name in direct_data.collections:
            technical_collection.unassign(direct_data)
        direct_pose.custom_shape = legacy_pose.custom_shape if legacy_pose else None
        direct_pose.use_custom_shape_bone_size = False
        if legacy_pose:
            direct_pose.custom_shape_scale_xyz = legacy_pose.custom_shape_scale_xyz
            direct_pose.color.palette = legacy_pose.color.palette
            direct_pose.color.custom.normal = legacy_pose.color.custom.normal
            direct_pose.color.custom.select = legacy_pose.color.custom.select
            direct_pose.color.custom.active = legacy_pose.color.custom.active
            legacy_pose.custom_shape = None
        if legacy_data and controls_collection and controls_collection.name in legacy_data.collections:
            controls_collection.unassign(legacy_data)
        if legacy_data and technical_collection and technical_collection.name not in legacy_data.collections:
            technical_collection.assign(legacy_data)

    configure_free_leg_constraints(armature)

    if needs_upgrade:
        for action in actions:
            armature.animation_data.action = action
            for frame in keyed_frames(action):
                bpy.context.scene.frame_set(int(round(frame)))
                for direct_name, (knee_position, _foot_matrix) in samples[(action.name, frame)].items():
                    knee = armature.pose.bones[direct_name]
                    matrix = knee.matrix.copy()
                    matrix.translation = knee_position
                    knee.matrix = matrix
                bpy.context.view_layer.update()
                for direct_name, (_knee_position, foot_matrix) in samples[(action.name, frame)].items():
                    armature.pose.bones[DIRECT_FEET[direct_name]].matrix = foot_matrix
                bpy.context.view_layer.update()
                for direct_name in DIRECT_KNEES:
                    for pose_bone in (
                        armature.pose.bones[direct_name],
                        armature.pose.bones[DIRECT_FEET[direct_name]],
                    ):
                        pose_bone.rotation_mode = "QUATERNION"
                        pose_bone.keyframe_insert("location", frame=frame, group=pose_bone.name)
                        pose_bone.keyframe_insert("rotation_quaternion", frame=frame, group=pose_bone.name)
                        pose_bone.keyframe_insert("scale", frame=frame, group=pose_bone.name)

        legacy_paths = tuple(f'pose.bones["{value[0]}"]' for value in DIRECT_KNEES.values())
        for action in actions:
            for layer in action.layers:
                for strip in layer.strips:
                    for channelbag in strip.channelbags:
                        for fcurve in list(channelbag.fcurves):
                            if fcurve.data_path.startswith(legacy_paths):
                                channelbag.fcurves.remove(fcurve)
        armature["rb_free_rotating_hips_v1"] = True

    armature.animation_data.action = previous_action
    bpy.context.scene.frame_set(previous_frame)
    bpy.context.view_layer.update()


def select_control(context, name, extend=False):
    armature = rig()
    context.view_layer.objects.active = armature
    armature.select_set(True)
    if armature.mode != "POSE":
        bpy.ops.object.mode_set(mode="POSE")
    if not extend:
        bpy.ops.pose.select_all(action="DESELECT")
    armature.pose.bones[name].select = True
    armature.data.bones.active = armature.data.bones[name]
    if name in DIRECT_ELBOWS or name in DIRECT_KNEES:
        for area in context.screen.areas if context.screen else ():
            if area.type != "VIEW_3D":
                continue
            area.spaces.active.show_gizmo = True
            try:
                with context.temp_override(area=area, space_data=area.spaces.active):
                    bpy.ops.wm.tool_set_by_id(name="builtin.move")
            except RuntimeError:
                pass


def set_view(context, axis):
    if not context.screen:
        return False
    for area in context.screen.areas:
        if area.type != "VIEW_3D":
            continue
        region = next((item for item in area.regions if item.type == "WINDOW"), None)
        if not region:
            continue
        space = area.spaces.active
        space.show_region_ui = True
        space.overlay.show_relationship_lines = False
        space.shading.type = "MATERIAL"
        with context.temp_override(area=area, region=region, space_data=space):
            bpy.ops.view3d.view_axis(type=axis, align_active=False)
        armature = rig()
        points = [point for bone in armature.data.bones for point in (bone.head_local, bone.tail_local)]
        min_z = min(point.z for point in points)
        max_z = max(point.z for point in points)
        height = max_z - min_z
        space.region_3d.view_location = armature.matrix_world @ Vector((0.0, 0.0, (min_z + max_z) * 0.5))
        space.region_3d.view_distance = height * 1.25
        return True
    return False


def return_home(context, status="Choisis la position vulnerable, la garde ou un coup."):
    armature = rig()
    neutral = neutral_action()
    armature.animation_data_create()
    armature.animation_data.action = neutral
    context.scene.frame_set(1)
    context.scene.rb2_mode = "HOME"
    context.scene.rb2_status = status


class RB2_OT_SelectControl(bpy.types.Operator):
    bl_idname = "rb2.select_control"
    bl_label = "Selectionner une poignee"

    bone_name: bpy.props.StringProperty()

    def invoke(self, context, event):
        armature = rig()
        if not armature or self.bone_name not in armature.pose.bones:
            return {"CANCELLED"}
        select_control(context, self.bone_name, extend=event.shift)
        return {"FINISHED"}

    def execute(self, context):
        armature = rig()
        if not armature or self.bone_name not in armature.pose.bones:
            return {"CANCELLED"}
        select_control(context, self.bone_name, extend=False)
        return {"FINISHED"}


class RB2_OT_ViewFace(bpy.types.Operator):
    bl_idname = "rb2.view_face"
    bl_label = "FACE"

    def execute(self, context):
        return {"FINISHED"} if set_view(context, "RIGHT") else {"CANCELLED"}


class RB2_OT_ViewProfile(bpy.types.Operator):
    bl_idname = "rb2.view_profile"
    bl_label = "PROFIL DU JEU"

    def execute(self, context):
        # Axe mondial fixe correspondant au combattant de gauche dans le jeu.
        # align_active=False dans set_view garantit qu'une rotation du bassin
        # ou d'un autre controle ne peut jamais retourner cette camera.
        return {"FINISHED"} if set_view(context, "FRONT") else {"CANCELLED"}


class RB2_OT_Home(bpy.types.Operator):
    bl_idname = "rb2.home"
    bl_label = "RETOUR AU CHOIX"

    def execute(self, context):
        return_home(context)
        return {"FINISHED"}


class RB2_OT_OpenNeutral(bpy.types.Operator):
    bl_idname = "rb2.open_neutral"
    bl_label = "CREER / MODIFIER LA POSITION VULNERABLE"

    def execute(self, context):
        armature = rig()
        action = neutral_action()
        if not armature or not action:
            return {"CANCELLED"}
        armature.animation_data_create()
        armature.animation_data.action = action
        context.scene.frame_start = 1
        context.scene.frame_end = 31
        context.scene.frame_set(1)
        context.scene.rb2_mode = "NEUTRAL"
        context.scene.rb2_status = "Tu modifies uniquement la POSITION VULNERABLE."
        return {"FINISHED"}


class RB2_OT_SaveNeutral(bpy.types.Operator):
    bl_idname = "rb2.save_neutral"
    bl_label = "1. ENREGISTRER LA POSITION"

    def execute(self, context):
        armature = rig()
        action = neutral_action()
        if (context.scene.rb2_mode != "NEUTRAL" or not armature or not action
                or armature.animation_data.action != action):
            self.report({"ERROR"}, "La position vulnerable n'est pas ouverte")
            return {"CANCELLED"}
        pose = capture_pose(armature)
        action["rb_neutral_authored_v2"] = True
        for frame in (1, 31):
            context.scene.frame_set(frame)
            apply_pose(armature, pose)
            key_pose(armature, frame)
        set_linear(action)
        context.scene.frame_set(1)
        apply_pose(armature, pose)
        save_blend()
        context.scene.rb2_status = "Position vulnerable enregistree. Le reste est intact."
        return {"FINISHED"}


class RB2_OT_ExportNeutral(bpy.types.Operator):
    bl_idname = "rb2.export_neutral"
    bl_label = "2. EXPORTER UNIQUEMENT CETTE POSITION"

    def execute(self, context):
        armature = rig()
        action = neutral_action()
        if (context.scene.rb2_mode != "NEUTRAL" or not armature or not action
                or armature.animation_data.action != action):
            self.report({"ERROR"}, "La position vulnerable n'est pas ouverte")
            return {"CANCELLED"}
        if not bool(action.get("rb_neutral_authored_v2", False)):
            self.report({"ERROR"}, "Enregistre d'abord ta position vulnerable")
            return {"CANCELLED"}
        try:
            export_active_action(output_dir() / "neutral.glb", action, 31)
        except RuntimeError as error:
            context.scene.rb2_status = str(error)
            self.report({"ERROR"}, str(error))
            return {"CANCELLED"}
        data = manifest_data()
        data["version"] = 3
        data["neutral"] = {
            "animation_file": "user://attacks/neutral.glb",
            "animation": "NEUTRE",
            "support": "both",
            "source_forward": SOURCE_FORWARD,
            "rig_id": CANONICAL_RIG_ID,
        }
        write_manifest(data)
        context.scene.rb2_status = "Position vulnerable exportee. Le reste est intact."
        return {"FINISHED"}


class RB2_OT_OpenGuard(bpy.types.Operator):
    bl_idname = "rb2.open_guard"
    bl_label = "CREER / MODIFIER LA GARDE"

    def execute(self, context):
        armature = rig()
        action = guard_action()
        if not armature or not action:
            return {"CANCELLED"}
        armature.animation_data_create()
        armature.animation_data.action = action
        context.scene.frame_start = 1
        context.scene.frame_end = 31
        context.scene.frame_set(1)
        context.scene.rb2_mode = "GUARD"
        context.scene.rb2_status = "Tu modifies uniquement la GARDE."
        return {"FINISHED"}


class RB2_OT_SaveGuard(bpy.types.Operator):
    bl_idname = "rb2.save_guard"
    bl_label = "1. ENREGISTRER LA GARDE"

    def execute(self, context):
        armature = rig()
        action = guard_action()
        if (context.scene.rb2_mode != "GUARD" or not armature or not action
                or armature.animation_data.action != action):
            self.report({"ERROR"}, "La garde n'est pas ouverte")
            return {"CANCELLED"}
        pose = capture_pose(armature)
        action["rb_guard_authored_v2"] = True
        context.scene.frame_set(1)
        apply_pose(armature, pose)
        key_pose(armature, 1)
        context.scene.frame_set(31)
        apply_pose(armature, pose)
        key_pose(armature, 31)
        set_linear(action)
        for move_action in user_actions():
            armature.animation_data.action = move_action
            frames = action_frames(move_action)
            for slot in ("guard", "preparation", "return"):
                if slot == "preparation" and bool(move_action.get("rb_custom_preparation", False)):
                    continue
                if slot == "return" and bool(move_action.get("rb_custom_return", False)):
                    continue
                context.scene.frame_set(frames[slot])
                apply_pose(armature, pose)
                key_pose(armature, frames[slot])
            set_linear(move_action)
        armature.animation_data.action = action
        context.scene.frame_set(1)
        apply_pose(armature, pose)
        save_blend()
        context.scene.rb2_status = (
            "Garde enregistree. Les impacts des coups restent intacts ; seules les poses "
            "encore liees a la garde sont mises a jour.")
        return {"FINISHED"}


class RB2_OT_ExportGuard(bpy.types.Operator):
    bl_idname = "rb2.export_guard"
    bl_label = "2. EXPORTER UNIQUEMENT LA GARDE"

    def execute(self, context):
        armature = rig()
        action = guard_action()
        if (context.scene.rb2_mode != "GUARD" or not armature or not action
                or armature.animation_data.action != action):
            self.report({"ERROR"}, "La garde n'est pas ouverte")
            return {"CANCELLED"}
        if not bool(action.get("rb_guard_authored_v2", False)):
            self.report({"ERROR"}, "Enregistre d'abord ta garde")
            return {"CANCELLED"}
        try:
            export_active_action(output_dir() / "guard.glb", action, 31)
        except RuntimeError as error:
            context.scene.rb2_status = str(error)
            self.report({"ERROR"}, str(error))
            return {"CANCELLED"}
        data = manifest_data()
        data["version"] = 3
        data["guard"] = {
            "animation_file": "user://attacks/guard.glb",
            "animation": "GARDE",
            "support": "both",
            "source_forward": SOURCE_FORWARD,
            "rig_id": CANONICAL_RIG_ID,
        }
        write_manifest(data)
        context.scene.rb2_status = "Garde exportee. Les coups n'ont pas ete modifies."
        return {"FINISHED"}


class RB2_OT_OpenCrouch(bpy.types.Operator):
    bl_idname = "rb2.open_crouch"
    bl_label = "CREER / MODIFIER LA POSITION ACCROUPIE"

    def execute(self, context):
        armature = rig()
        action = crouch_action(create=True)
        if not armature or not action:
            return {"CANCELLED"}
        armature.animation_data_create()
        armature.animation_data.action = action
        context.scene.frame_start = 1
        context.scene.frame_end = 31
        context.scene.frame_set(1)
        context.scene.rb2_mode = "CROUCH"
        context.scene.rb2_status = "Tu modifies uniquement la POSITION ACCROUPIE."
        return {"FINISHED"}


class RB2_OT_SaveCrouch(bpy.types.Operator):
    bl_idname = "rb2.save_crouch"
    bl_label = "1. ENREGISTRER LA POSITION ACCROUPIE"

    def execute(self, context):
        armature = rig()
        action = crouch_action()
        if (context.scene.rb2_mode != "CROUCH" or not armature or not action
                or armature.animation_data.action != action):
            self.report({"ERROR"}, "La position accroupie n'est pas ouverte")
            return {"CANCELLED"}
        pose = capture_pose(armature)
        action["rb_crouch_authored_v1"] = True
        for frame in (1, 31):
            context.scene.frame_set(frame)
            apply_pose(armature, pose)
            key_pose(armature, frame)
        set_linear(action)
        context.scene.frame_set(1)
        apply_pose(armature, pose)
        save_blend()
        context.scene.rb2_status = "Position accroupie enregistree. Le reste est intact."
        return {"FINISHED"}


class RB2_OT_ExportCrouch(bpy.types.Operator):
    bl_idname = "rb2.export_crouch"
    bl_label = "2. EXPORTER UNIQUEMENT CETTE POSITION"

    def execute(self, context):
        armature = rig()
        action = crouch_action()
        if (context.scene.rb2_mode != "CROUCH" or not armature or not action
                or armature.animation_data.action != action):
            self.report({"ERROR"}, "La position accroupie n'est pas ouverte")
            return {"CANCELLED"}
        if not bool(action.get("rb_crouch_authored_v1", False)):
            self.report({"ERROR"}, "Enregistre d'abord ta position accroupie")
            return {"CANCELLED"}
        try:
            export_active_action(output_dir() / "crouch.glb", action, 31)
        except RuntimeError as error:
            context.scene.rb2_status = str(error)
            self.report({"ERROR"}, str(error))
            return {"CANCELLED"}
        data = manifest_data()
        data["version"] = 3
        data["crouch"] = {
            "animation_file": "user://attacks/crouch.glb",
            "animation": "ACCROUPI",
            "support": "both",
            "source_forward": SOURCE_FORWARD,
            "rig_id": CANONICAL_RIG_ID,
        }
        write_manifest(data)
        context.scene.rb2_status = "Position accroupie exportee. Les autres animations sont intactes."
        return {"FINISHED"}


class RB2_OT_CreateMove(bpy.types.Operator):
    bl_idname = "rb2.create_move"
    bl_label = "CREER CE COUP"

    def execute(self, context):
        armature = rig()
        guard = guard_action()
        move = context.scene.rb2_new_move
        if not armature or not guard:
            return {"CANCELLED"}
        if not bool(guard.get("rb_guard_authored_v2", False)):
            context.scene.rb2_status = "Cree et enregistre d'abord ta garde."
            self.report({"WARNING"}, context.scene.rb2_status)
            return {"CANCELLED"}
        if bpy.data.actions.get(move):
            context.scene.rb2_status = "Ce coup existe deja : ouvre-le au lieu de le recreer."
            return {"CANCELLED"}
        defaults = DEFAULTS.get(move, (6, 4, 10, 8))
        context.scene.rb2_startup = defaults[0]
        context.scene.rb2_active = defaults[1]
        context.scene.rb2_recovery = defaults[2]
        context.scene.rb2_keep_end_position = False
        pose = guard_pose(context)
        action = bpy.data.actions.new(move)
        action.use_fake_user = True
        action["rb_user_move_v2"] = True
        action["rb_custom_preparation"] = False
        action["rb_custom_return"] = False
        action["rb_impact_authored"] = False
        armature.animation_data.action = action
        store_settings(context.scene, action)
        frames = action_frames(action)
        for frame in sorted(set(frames.values())):
            context.scene.frame_set(frame)
            apply_pose(armature, pose)
            key_pose(armature, frame)
        set_linear(action)
        context.scene.rb2_mode = "MOVE"
        context.scene.rb2_active_move = move
        context.scene.rb2_existing_move = move
        context.scene.rb2_pose = "impact"
        context.scene.frame_start = 1
        context.scene.frame_end = frames["return"]
        context.scene.frame_set(frames["impact"])
        save_blend()
        context.scene.rb2_status = f"{MOVE_LABELS[move]} cree. Modifie maintenant ses trois poses."
        return {"FINISHED"}


class RB2_OT_OpenMove(bpy.types.Operator):
    bl_idname = "rb2.open_move"
    bl_label = "OUVRIR CE COUP"

    def execute(self, context):
        move = context.scene.rb2_existing_move
        action = bpy.data.actions.get(move)
        armature = rig()
        if move == "__none__" or not action or not bool(action.get("rb_user_move_v2", False)):
            context.scene.rb2_status = "Aucun coup personnel n'existe encore."
            return {"CANCELLED"}
        armature.animation_data.action = action
        load_settings(context.scene, action)
        context.scene.rb2_mode = "MOVE"
        context.scene.rb2_active_move = move
        context.scene.rb2_pose = "impact"
        context.scene.frame_set(action_frames(action)["impact"])
        context.scene.rb2_status = f"Tu modifies uniquement : {MOVE_LABELS.get(move, move)}."
        return {"FINISHED"}


class RB2_OT_OpenPose(bpy.types.Operator):
    bl_idname = "rb2.open_pose"
    bl_label = "Ouvrir une pose"

    slot: bpy.props.StringProperty()

    def execute(self, context):
        action = bpy.data.actions.get(context.scene.rb2_active_move)
        armature = rig()
        if context.scene.rb2_mode != "MOVE" or not action or armature.animation_data.action != action:
            return {"CANCELLED"}
        context.scene.rb2_pose = self.slot
        context.scene.frame_set(action_frames(action)[self.slot])
        context.scene.rb2_status = f"Pose ouverte : {POSE_LABELS[self.slot]}."
        return {"FINISHED"}


class RB2_OT_SaveMovePose(bpy.types.Operator):
    bl_idname = "rb2.save_move_pose"
    bl_label = "ENREGISTRER CETTE POSE"

    def execute(self, context):
        move = context.scene.rb2_active_move
        action = bpy.data.actions.get(move)
        armature = rig()
        slot = context.scene.rb2_pose
        frame = action_frames(action)[slot] if action else -1
        if (context.scene.rb2_mode != "MOVE" or not action or not armature
                or armature.animation_data.action != action or context.scene.frame_current != frame):
            self.report({"ERROR"}, "Rouvre la pose avant de l'enregistrer")
            return {"CANCELLED"}
        key_pose(armature, frame)
        if slot == "preparation":
            action["rb_custom_preparation"] = True
        elif slot == "impact":
            action["rb_impact_authored"] = True
        elif slot == "return":
            action["rb_custom_return"] = True
        set_linear(action)
        save_blend()
        context.scene.rb2_status = f"{POSE_LABELS[slot]} enregistree pour {MOVE_LABELS.get(move, move)}."
        return {"FINISHED"}


class RB2_OT_CopyGuard(bpy.types.Operator):
    bl_idname = "rb2.copy_guard"
    bl_label = "REMETTRE CETTE POSE = GARDE"

    def execute(self, context):
        move = context.scene.rb2_active_move
        action = bpy.data.actions.get(move)
        armature = rig()
        slot = context.scene.rb2_pose
        if not action or slot not in ("preparation", "return"):
            return {"CANCELLED"}
        pose = guard_pose(context)
        armature.animation_data.action = action
        frame = action_frames(action)[slot]
        context.scene.frame_set(frame)
        apply_pose(armature, pose)
        key_pose(armature, frame)
        action["rb_custom_preparation" if slot == "preparation" else "rb_custom_return"] = False
        set_linear(action)
        save_blend()
        context.scene.rb2_status = f"{POSE_LABELS[slot]} remise sur la garde."
        return {"FINISHED"}


class RB2_OT_ApplyTimings(bpy.types.Operator):
    bl_idname = "rb2.apply_timings"
    bl_label = "APPLIQUER LES DUREES"

    def execute(self, context):
        move = context.scene.rb2_active_move
        old_action = bpy.data.actions.get(move)
        armature = rig()
        if not old_action or context.scene.rb2_mode != "MOVE":
            return {"CANCELLED"}
        old_frames = action_frames(old_action)
        poses = {slot: read_pose(context, old_action, frame) for slot, frame in old_frames.items()}
        properties = {key: old_action[key] for key in old_action.keys()}
        replacement = bpy.data.actions.new(move + "_timings")
        replacement.use_fake_user = True
        armature.animation_data.action = replacement
        new_frames = scene_frames(context.scene)
        for slot, frame in new_frames.items():
            context.scene.frame_set(frame)
            apply_pose(armature, poses[slot])
            key_pose(armature, frame)
        for key, value in properties.items():
            replacement[key] = value
        replacement["rb_user_move_v2"] = True
        store_settings(context.scene, replacement)
        set_linear(replacement)
        armature.animation_data.action = replacement
        bpy.data.actions.remove(old_action)
        replacement.name = move
        context.scene.frame_start = 1
        context.scene.frame_end = new_frames["return"]
        context.scene.frame_set(new_frames[context.scene.rb2_pose])
        save_blend()
        context.scene.rb2_status = "Durees appliquees sans changer les poses."
        return {"FINISHED"}


class RB2_OT_ExportMove(bpy.types.Operator):
    bl_idname = "rb2.export_move"
    bl_label = "EXPORTER UNIQUEMENT CE COUP"

    def execute(self, context):
        move = context.scene.rb2_active_move
        action = bpy.data.actions.get(move)
        armature = rig()
        if (context.scene.rb2_mode != "MOVE" or not action or not armature
                or armature.animation_data.action != action or not bool(action.get("rb_user_move_v2", False))):
            self.report({"ERROR"}, "Le coup affiche n'est pas valide")
            return {"CANCELLED"}
        if not bool(action.get("rb_impact_authored", False)):
            self.report({"ERROR"}, "Enregistre d'abord la pose IMPACT de ce coup")
            context.scene.rb2_status = "Export refuse : la pose IMPACT n'a pas encore ete creee."
            return {"CANCELLED"}
        if action_frames(action) != scene_frames(context.scene):
            self.report({"ERROR"}, "Applique d'abord les durees")
            return {"CANCELLED"}
        action["rb_keep_end_position"] = bool(context.scene.rb2_keep_end_position)
        movement = root_motion_curve(action) if context.scene.rb2_keep_end_position else []
        frames = action_frames(action)
        try:
            export_active_action(output_dir() / f"{move}.glb", action, frames["return"])
        except RuntimeError as error:
            context.scene.rb2_status = str(error)
            self.report({"ERROR"}, str(error))
            return {"CANCELLED"}
        data = manifest_data()
        data["version"] = 3
        data["slots"][MOVE_SLOTS[move]] = move
        defaults = DEFAULTS.get(move, (6, 4, 10, 8))
        move_data = {
            "animation_file": f"user://attacks/{move}.glb",
            "animation": move,
            "startup": context.scene.rb2_startup / 60.0,
            "active": context.scene.rb2_active / 60.0,
            "recover": context.scene.rb2_recovery / 60.0,
            "dmg": defaults[3],
            "support": "none" if move.startswith("air_") or move == "dive_kick" else "auto",
            "source_forward": SOURCE_FORWARD,
            "rig_id": CANONICAL_RIG_ID,
        }
        previous_move = data.get("moves", {}).get(move, {})
        if isinstance(previous_move, dict):
            for key in (
                "box", "radius", "radius_x", "radius_y", "hitbox_shape",
                "kb", "hitstun", "blockstun", "hitbox_authored",
            ):
                if key in previous_move:
                    move_data[key] = previous_move[key]
        if movement:
            move_data["root_motion_curve"] = movement
        data["moves"][move] = move_data
        write_manifest(data)
        save_blend()
        suffix = " Position finale conservee." if movement else ""
        context.scene.rb2_status = f"{MOVE_LABELS.get(move, move)} exporte.{suffix} La garde n'a pas ete modifiee."
        return {"FINISHED"}


def draw_controls(layout):
    box = layout.box()
    box.label(text="1 CLIC SUR CE QUE TU VEUX BOUGER")

    def button(parent, text, name):
        operator = parent.operator("rb2.select_control", text=text)
        operator.bone_name = name

    row = box.row(align=True)
    button(row, "Main BLEUE", "MAIN_BLEUE")
    button(row, "Main ROUGE", "MAIN_ROUGE")
    row = box.row(align=True)
    button(row, "Coude BLEU", "COUDE_3D_BLEU")
    button(row, "Coude ROUGE", "COUDE_3D_ROUGE")
    row = box.row(align=True)
    button(row, "Genou BLEU", "GENOU_3D_BLEU")
    button(row, "Genou ROUGE", "GENOU_3D_ROUGE")
    row = box.row(align=True)
    button(row, "Pied BLEU", "PIED_BLEU")
    button(row, "Pied ROUGE", "PIED_ROUGE")
    row = box.row(align=True)
    button(row, "Bassin", "BASSIN")
    button(row, "Torse", "TORSE")
    button(row, "Tete", "TETE")
    button(box, "Corps entier", "CORPS_ENTIER")
    box.label(text="G = deplacer   |   R = tourner")
    box.label(text="Maj + clic sur un bouton = ajouter a la selection")
    box.label(text="Coude : tourne l'epaule fixe dans les 3 axes")
    box.label(text="La main suit, puis reste reglable separement")
    box.label(text="Genou : meme principe pour la hanche et le pied")
    row = box.row(align=True)
    row.operator("rb2.view_face")
    row.operator("rb2.view_profile")


class RB2_PT_Panel(bpy.types.Panel):
    bl_label = "Ragdoll Brawl"
    bl_idname = "RB2_PT_panel"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Ragdoll Brawl"

    def draw(self, context):
        layout = self.layout
        scene = context.scene

        if scene.rb2_mode == "HOME":
            title = layout.box()
            title.label(text="ATELIER PROPRE", icon="ARMATURE_DATA")
            title.label(text="Ce pantin anime tous les futurs skins.")
            title.operator("rb2.open_neutral", icon="OUTLINER_OB_ARMATURE")
            title.operator("rb2.open_guard", icon="POSE_HLT")
            title.operator("rb2.open_crouch", icon="MOD_ARMATURE")

            existing = layout.box()
            existing.label(text="MES COUPS CREES")
            existing.prop(scene, "rb2_existing_move", text="")
            existing.operator("rb2.open_move")

            create = layout.box()
            create.label(text="CREER UN NOUVEAU COUP")
            create.prop(scene, "rb2_new_move", text="")
            create.operator("rb2.create_move", icon="ADD")
            create.label(text="Le nouveau coup part toujours de ta garde.")
            if scene.rb2_status:
                layout.label(text=scene.rb2_status, icon="INFO")
            return

        header = layout.box()
        header.alert = True
        if scene.rb2_mode == "NEUTRAL":
            header.label(text="TU MODIFIES UNIQUEMENT : POSITION VULNERABLE")
        elif scene.rb2_mode == "GUARD":
            header.label(text="TU MODIFIES UNIQUEMENT : GARDE")
        elif scene.rb2_mode == "CROUCH":
            header.label(text="TU MODIFIES UNIQUEMENT : POSITION ACCROUPIE")
        else:
            header.label(text=f"TU MODIFIES UNIQUEMENT : {MOVE_LABELS.get(scene.rb2_active_move, scene.rb2_active_move)}")
        header.operator("rb2.home", icon="BACK")
        draw_controls(layout)

        if scene.rb2_mode == "NEUTRAL":
            box = layout.box()
            box.label(text="POSITION VULNERABLE")
            box.operator("rb2.save_neutral", icon="KEY_HLT")
            box.operator("rb2.export_neutral", icon="EXPORT")
            box.label(text="Cet export ne modifie rien d'autre.")
        elif scene.rb2_mode == "GUARD":
            box = layout.box()
            box.label(text="GARDE")
            box.operator("rb2.save_guard", icon="KEY_HLT")
            box.operator("rb2.export_guard", icon="EXPORT")
            box.label(text="Ce bouton exporte uniquement la garde.")
        elif scene.rb2_mode == "CROUCH":
            box = layout.box()
            box.label(text="POSITION ACCROUPIE")
            box.operator("rb2.save_crouch", icon="KEY_HLT")
            box.operator("rb2.export_crouch", icon="EXPORT")
            box.label(text="Les coups hauts passent au-dessus dans le jeu.")
        else:
            pose = layout.box()
            pose.label(text="CHOISIS UNE POSE")
            row = pose.row(align=True)
            for slot, label in (("preparation", "PREPARATION"), ("impact", "IMPACT"), ("return", "RETOUR")):
                operator = row.operator("rb2.open_pose", text=label, depress=scene.rb2_pose == slot)
                operator.slot = slot
            pose.label(text=f"Pose ouverte : {POSE_LABELS[scene.rb2_pose]}")
            pose.operator("rb2.save_move_pose", icon="KEY_HLT")
            if scene.rb2_pose == "impact":
                pose.label(text="L'impact doit etre enregistre avant le premier export.")
            if scene.rb2_pose in ("preparation", "return"):
                pose.operator("rb2.copy_guard", icon="LOOP_BACK")

            timing = layout.box()
            timing.label(text="DUREES EN IMAGES (60 / SECONDE)")
            timing.prop(scene, "rb2_startup", text="Avant impact")
            timing.prop(scene, "rb2_active", text="Impact")
            timing.prop(scene, "rb2_recovery", text="Retour")
            timing.operator("rb2.apply_timings")

            movement = layout.box()
            movement.label(text="DEPLACEMENT DU COMBATTANT")
            movement.prop(scene, "rb2_keep_end_position", text="Garder la position finale")
            movement.label(text="Utilise le deplacement du bassin jusqu'au RETOUR.")

            export = layout.box()
            export.operator("rb2.export_move", icon="EXPORT")
            export.label(text="Ce bouton ne peut jamais exporter la garde.")

        if scene.rb2_status:
            layout.label(text=scene.rb2_status, icon="INFO")


CLASSES = (
    RB2_OT_SelectControl,
    RB2_OT_ViewFace,
    RB2_OT_ViewProfile,
    RB2_OT_Home,
    RB2_OT_OpenNeutral,
    RB2_OT_SaveNeutral,
    RB2_OT_ExportNeutral,
    RB2_OT_OpenGuard,
    RB2_OT_SaveGuard,
    RB2_OT_ExportGuard,
    RB2_OT_OpenCrouch,
    RB2_OT_SaveCrouch,
    RB2_OT_ExportCrouch,
    RB2_OT_CreateMove,
    RB2_OT_OpenMove,
    RB2_OT_OpenPose,
    RB2_OT_SaveMovePose,
    RB2_OT_CopyGuard,
    RB2_OT_ApplyTimings,
    RB2_OT_ExportMove,
    RB2_PT_Panel,
)


def register():
    for cls in CLASSES:
        try:
            bpy.utils.register_class(cls)
        except RuntimeError:
            pass
    scene_type = bpy.types.Scene
    scene_type.rb2_mode = bpy.props.EnumProperty(
        items=[
            ("HOME", "Accueil", ""),
            ("NEUTRAL", "Position vulnerable", ""),
            ("GUARD", "Garde", ""),
            ("CROUCH", "Position accroupie", ""),
            ("MOVE", "Coup", ""),
        ],
        default="HOME",
    )
    scene_type.rb2_status = bpy.props.StringProperty(default="")
    scene_type.rb2_existing_move = bpy.props.EnumProperty(items=existing_move_items)
    scene_type.rb2_new_move = bpy.props.EnumProperty(items=MOVES, default="jab")
    scene_type.rb2_active_move = bpy.props.StringProperty(default="")
    scene_type.rb2_pose = bpy.props.EnumProperty(
        items=[
            ("preparation", "Preparation", ""),
            ("impact", "Impact", ""),
            ("return", "Retour", ""),
        ],
        default="impact",
    )
    scene_type.rb2_startup = bpy.props.IntProperty(min=2, max=120, default=6)
    scene_type.rb2_active = bpy.props.IntProperty(min=1, max=30, default=4)
    scene_type.rb2_recovery = bpy.props.IntProperty(min=1, max=120, default=10)
    scene_type.rb2_keep_end_position = bpy.props.BoolProperty(default=False)
    armature = rig()
    if armature:
        crouch_action(create=True)
        armature.animation_data_create()
        armature.animation_data.action = neutral_action()
        lock_and_hide_shoulders(armature)
        ensure_direct_elbow_controls(armature)
        ensure_free_rotating_shoulders(armature)
        ensure_free_rotating_hips(armature)
        show_controls(armature)
        bpy.context.view_layer.objects.active = armature
        armature.select_set(True)
        if armature.mode != "POSE":
            try:
                bpy.ops.object.mode_set(mode="POSE")
            except RuntimeError:
                pass
        bpy.context.scene.frame_set(1)
        bpy.context.scene.rb2_mode = "HOME"
        bpy.context.scene.rb2_status = "Atelier propre : cree d'abord ta garde."
    if bpy.context.screen:
        set_view(bpy.context, "RIGHT")


def unregister():
    for cls in reversed(CLASSES):
        try:
            bpy.utils.unregister_class(cls)
        except RuntimeError:
            pass


if __name__ == "__main__":
    register()
