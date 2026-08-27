extends CharacterBody2D
class_name Fighter

# ============================================================
#  Combattant : corps cinematique + squelette dessine en code.
#  Plus de ragdoll -> le perso tient debout et se deplace.
#
#  Triangle conserve :
#    GRAB     bat  GARDE
#    GARDE    bat  FRAPPE
#    FRAPPE   bat  GRAB   (latence longue = punissable)
# ============================================================

signal hp_changed
signal ko

enum State { IDLE, WALK, CROUCH, AIR, ATTACK, BLOCK, GRAB, GRABBING, GRABBED, HURT, KO }

const MAX_HP        := 160.0
const GRAVITY       := 2000.0
const FORWARD_SPEED := 225.0
const BACK_SPEED    := 180.0
const SPEED         := FORWARD_SPEED # compatibilite avec les scenes de test
const GROUND_ACCEL  := 3800.0
const GROUND_BRAKE  := 4800.0
const AIR_SPEED     := 200.0
const JUMP_VEL      := -740.0
const CROUCH_SPEED  := 90.0

# Fenetre de memorisation d'un appui. Assez large pour couvrir la fin d'une
# grosse recuperation, assez courte pour ne pas declencher un coup "fantome"
# qu'on n'a plus voulu.
const BUFFER_TIME   := 0.16
const BLOCK_RAISE   := 0.16
const BLOCK_DRAIN   := 0.0   # 0 = la garde ne se vide QUE sur impact
const BLOCK_REGEN   := 0.26
const BLOCK_BREAK   := 1.10
const CHIP_RATIO    := 0.16
# Drain de garde proportionnel aux degats : casser une garde demande de placer
# de gros coups, pas de repeter le plus rapide. Avec la constante forfaitaire
# d'avant, le jab cassait la garde deux fois plus vite qu'un coup de pied saute.
const GUARD_DRAIN   := 0.022
# Recul en garde : seul le defenseur glisse, l'attaquant ne bouge pas. C'est ce
# qui recree la distance et empeche un coup rapide de boucler sur place.
const BLOCK_PUSH_BASE    := 200.0
const BLOCK_PUSH_PER_DMG := 12.0

const GRAB_STARTUP  := 0.06
const GRAB_ACTIVE   := 0.14
const GRAB_WHIFF    := 0.34   # reste la fenetre de punition du grab rate
const GRAB_HOLD     := 1.10
const THROW_RELEASE := 0.18
const THROW_DAMAGE  := 16.0

# Projections : une fois l'adversaire saisi, une direction lance la projection
# de ce cote. kb.x est exprime dans le repere "vers l'avant".
const THROWS := {
	"front": {"kb": Vector2(640, -180), "dmg": 1.05, "stun": 0.58, "pose": "boot_throw"},
	"back":  {"kb": Vector2(-620, -360), "dmg": 1.15, "stun": 0.68, "pose": "tomoe"},
	"up":    {"kb": Vector2(150, -780), "dmg": 1.05, "stun": 0.70, "pose": "grab_uppercut"},
	"down":  {"kb": Vector2(120, 420), "dmg": 1.40, "stun": 0.72, "pose": "knee_crush"},
}
const ESCAPE_NEEDED := 5.0
const ESCAPE_DECAY  := 3.0
const GRAB_PUNISH   := 0.80
const HEAD_DAMAGE_MULTIPLIER := 1.20

# ============================================================
#  TABLE DES ATTAQUES  <- tout le tuning est ici
#  box  : centre de la hitbox (x vers l'avant, y vers le haut negatif)
#  dmg  : degats     hitstun : stun inflige     blockstun : garde adverse
# ============================================================
const MOVES := {
	"jab": {
		"startup": 0.05, "active": 0.05, "recover": 0.15,
		"box": Vector2(42, -82), "radius": 18.0,
		"dmg": 5.5, "kb": Vector2(260, -40), "hitstun": 0.2167, "blockstun": 0.15,
		"pose": "punch_mid",
	},
	"uppercut": {
		"startup": 0.25, "active": 0.0833, "recover": 0.2667,
		"box": Vector2(34, -84), "radius": 24.0,
		"dmg": 15.0, "kb": Vector2(140, -420), "hitstun": 0.4167, "blockstun": 0.15,
		"pose": "punch_up",
	},
	"body_hook": {
		"startup": 0.1667, "active": 0.1333, "recover": 0.2,
		"box": Vector2(38, -52), "radius": 19.0,
		"dmg": 12.0, "kb": Vector2(240, -45), "hitstun": 0.3167, "blockstun": 0.1667,
		"pose": "body_hook",
	},
	"hook": {
		"startup": 0.1333, "active": 0.1333, "recover": 0.2167,
		"box": Vector2(40, -88), "radius": 19.0,
		"dmg": 13.0, "kb": Vector2(330, -105), "hitstun": 0.35, "blockstun": 0.1667,
		"pose": "hook",
	},
	"spinning_backfist": {
		"startup": 0.25, "active": 0.0833, "recover": 0.2833,
		"box": Vector2(47, -78), "radius": 21.0,
		"dmg": 19.0, "kb": Vector2(410, -150), "hitstun": 0.45, "blockstun": 0.15,
		"pose": "spinning_backfist",
	},
	"air_punch": {
		"startup": 0.1, "active": 0.0667, "recover": 0.1667,
		"box": Vector2(42, -46), "radius": 22.0,
		"dmg": 7.0, "kb": Vector2(210, -140), "hitstun": 0.2667, "blockstun": 0.1667,
		"pose": "air_punch",
	},
	"air_upper": {
		"startup": 0.1, "active": 0.0667, "recover": 0.1833,
		"box": Vector2(30, -78), "radius": 23.0,
		"dmg": 9.0, "kb": Vector2(120, -340), "hitstun": 0.3333, "blockstun": 0.15,
		"pose": "air_upper",
	},
	"air_hammer": {
		"startup": 0.2333, "active": 0.0667, "recover": 0.1833,
		"box": Vector2(32, -20), "radius": 24.0,
		"dmg": 12.0, "kb": Vector2(150, 300), "hitstun": 0.3167, "blockstun": 0.15,
		"pose": "air_hammer",
	},
	"air_cross": {
		"startup": 0.1333, "active": 0.2667, "recover": 0.15,
		"box": Vector2(52, -48), "radius": 21.0,
		"dmg": 11.0, "kb": Vector2(300, -130), "hitstun": 0.2667, "blockstun": 0.1333,
		"pose": "air_cross",
	},
	"air_backfist": {
		"startup": 0.1, "active": 0.0667, "recover": 0.2,
		"box": Vector2(48, -55), "radius": 24.0,
		"dmg": 10.0, "kb": Vector2(350, -100), "hitstun": 0.3, "blockstun": 0.15,
		"pose": "air_backfist",
	},
	"middle_kick": {
		"startup": 0.1, "active": 0.0667, "recover": 0.2333,
		"box": Vector2(58, -48), "radius": 24.0,
		"dmg": 11.0, "kb": Vector2(430, -180), "hitstun": 0.3333, "blockstun": 0.1667,
		"pose": "middle_kick",
	},
	"high_kick": {
		"startup": 0.1167, "active": 0.0667, "recover": 0.2833,
		"box": Vector2(48, -84), "radius": 24.0,
		"dmg": 15.0, "kb": Vector2(300, -330), "hitstun": 0.4667, "blockstun": 0.1667,
		"pose": "kick_high",
	},
	"sweep": {
		"startup": 0.1167, "active": 0.0833, "recover": 0.3167,
		"box": Vector2(54, -16), "radius": 22.0,
		"dmg": 9.0, "kb": Vector2(150, -260), "hitstun": 0.6, "blockstun": 0.1833,
		"pose": "sweep",
	},
	"front_kick": {
		"startup": 0.2, "active": 0.1, "recover": 0.2,
		"box": Vector2(57, -43), "radius": 23.0,
		"dmg": 12.0, "kb": Vector2(370, -140), "hitstun": 0.3, "blockstun": 0.15,
		"pose": "front_kick",
	},
	"spinning_kick": {
		"startup": 0.2333, "active": 0.0833, "recover": 0.35,
		"box": Vector2(64, -52), "radius": 27.0,
		"dmg": 21.0, "kb": Vector2(520, -190), "hitstun": 0.5, "blockstun": 0.2,
		"pose": "spinning_kick",
	},
	"air_kick": {
		"startup": 0.1, "active": 0.0667, "recover": 0.1667,
		"box": Vector2(48, -42), "radius": 23.0,
		"dmg": 8.0, "kb": Vector2(290, -120), "hitstun": 0.2667, "blockstun": 0.15,
		"pose": "air_kick",
	},
	"air_rising_kick": {
		"startup": 0.3333, "active": 0.1, "recover": 0.2167,
		"box": Vector2(34, -80), "radius": 24.0,
		"dmg": 13.0, "kb": Vector2(150, -380), "hitstun": 0.3833, "blockstun": 0.1667,
		"pose": "air_rising_kick",
	},
	"dive_kick": {
		"startup": 0.3333, "active": 0.1, "recover": 0.2167,
		"box": Vector2(40, -18), "radius": 22.0,
		"dmg": 12.0, "kb": Vector2(240, 260), "hitstun": 0.3333, "blockstun": 0.1833,
		"pose": "dive",
	},
	"air_side_kick": {
		"startup": 0.1333, "active": 0.3333, "recover": 0.1833,
		"box": Vector2(59, -44), "radius": 24.0,
		"dmg": 13.0, "kb": Vector2(410, -150), "hitstun": 0.3167, "blockstun": 0.15,
		"pose": "air_side_kick",
	},
	"air_roundhouse": {
		"startup": 0.1, "active": 0.0667, "recover": 0.2333,
		"box": Vector2(56, -62), "radius": 27.0,
		"dmg": 13.0, "kb": Vector2(450, -210), "hitstun": 0.4167, "blockstun": 0.1667,
		"pose": "air_roundhouse",
	},
}

const KICK_MOVES := ["middle_kick", "high_kick", "sweep", "front_kick", "spinning_kick",
	"air_kick", "air_rising_kick", "dive_kick", "air_side_kick", "air_roundhouse"]
const AIR_MOVE_NAMES := ["air_punch", "air_upper", "air_hammer", "air_cross", "air_backfist",
	"air_kick", "air_rising_kick", "dive_kick", "air_side_kick", "air_roundhouse"]

# ============================================================
#  Poses (angles en radians, repere pour un perso tourne vers la DROITE ;
#  le rendu miroir pour l'autre sens est automatique via `facing`).
#
#    angle d'un membre : 0 = vers le bas, +PI/2 = vers l'adversaire,
#                        +PI = vers le haut, -PI/2 = vers l'arriere.
#    [0] = segment haut (epaule/hanche -> coude/genou)
#    [1] = flexion du segment bas (relatif au segment haut)
#    lean : + = se pencher en arriere, - = se pencher vers l'adversaire
#    drop : descente du bassin (accroupi, balayage...)
# ============================================================
const POSES := {
	"idle":      {"lean": 0.02, "drop": 4.0,
		"arm_b": [-0.10, 0.28], "arm_f": [-0.04, 0.25], "leg_b": [0.30, -0.50], "leg_f": [0.20, -0.58]},
	"walk":      {"lean": 0.03, "drop": 4.0,
		"arm_b": [-0.10, 0.28], "arm_f": [-0.04, 0.25], "leg_b": [0.30, -0.50], "leg_f": [0.20, -0.58]},
	"crouch":    {"lean": -0.10, "drop": 18.0,
		"arm_b": [0.55, 1.55], "arm_f": [0.45, 1.75], "leg_b": [0.72, -1.77], "leg_f": [1.22, -1.81]},
	"air":       {"lean": 0.05, "drop": -4.0,
		"arm_b": [0.85, 1.00], "arm_f": [-0.55, 0.04], "leg_b": [0.50, -1.15], "leg_f": [-0.35, -0.60]},
	"block":     {"lean": -0.10, "drop": 4.0,
		# Aucun dessin de garde prefabrique : tant que l'utilisateur n'a pas
		# exporte la sienne, le pantin reste dans la toile neutre bras bas.
		"arm_b": [-0.10, 0.28], "arm_f": [-0.04, 0.25], "leg_b": [0.30, -0.50], "leg_f": [0.20, -0.58]},
	"punch_mid": {"lean": -0.04, "drop": 4.0,
		"arm_b": [0.30, 2.05], "arm_f": [1.34, 0.40], "leg_b": [0.24, -0.30], "leg_f": [0.32, -0.46]},
	"punch_up":  {"lean": -0.15, "drop": 6.0,
		"arm_b": [0.55, 1.90], "arm_f": [2.70, 0.15], "leg_b": [0.50, -0.62], "leg_f": [0.38, -0.70]},
	"body_hook": {"lean": -0.12, "drop": 10.0,
		"arm_b": [0.34, 2.30], "arm_f": [1.02, 1.58], "leg_b": [0.62, -1.18], "leg_f": [0.78, -1.26]},
	"hook":      {"lean": -0.04, "drop": 5.0,
		"arm_b": [0.25, 2.30], "arm_f": [1.12, 1.62], "leg_b": [0.42, -0.54], "leg_f": [0.32, -0.48]},
	"spinning_backfist": {"lean": 0.12, "drop": 4.0,
		"arm_b": [0.58, 1.42], "arm_f": [-1.46, 0.04], "leg_b": [0.42, -0.48], "leg_f": [0.58, -0.64]},
	"air_punch": {"lean": -0.08, "drop": -4.0,
		"arm_b": [0.72, 1.10], "arm_f": [1.55, 0.02], "leg_b": [0.48, -1.10], "leg_f": [-0.28, -0.72]},
	"air_upper": {"lean": -0.18, "drop": -4.0,
		"arm_b": [0.55, 1.45], "arm_f": [2.68, 0.12], "leg_b": [0.62, -1.22], "leg_f": [-0.18, -0.82]},
	"air_hammer": {"lean": -0.22, "drop": -2.0,
		"arm_b": [1.90, 0.35], "arm_f": [0.20, 0.04], "leg_b": [0.42, -1.02], "leg_f": [-0.42, -0.90]},
	"air_cross": {"lean": -0.16, "drop": -4.0,
		"arm_b": [0.68, 1.40], "arm_f": [1.62, 0.00], "leg_b": [0.55, -1.12], "leg_f": [-0.22, -0.70]},
	"air_backfist": {"lean": 0.16, "drop": -4.0,
		"arm_b": [0.35, 1.55], "arm_f": [1.88, 0.08], "leg_b": [0.72, -1.30], "leg_f": [-0.48, -0.92]},
	"middle_kick": {"lean": 0.06, "drop": 1.0,
		"arm_b": [1.28, 0.30], "arm_f": [-0.72, 0.08], "leg_b": [0.30, -0.18], "leg_f": [1.43, -0.34]},
	"kick_high": {"lean": 0.30, "drop": 0.0,
		"arm_b": [1.30, 0.40], "arm_f": [-0.40, 0.05], "leg_b": [0.45, -0.15], "leg_f": [2.35, 0.00]},
	"sweep":     {"lean": -0.05, "drop": 30.0,
		"arm_b": [-0.95, 0.50], "arm_f": [1.05, 0.40], "leg_b": [1.00, -2.45], "leg_f": [1.27, 0.00]},
	"dive":      {"lean": -0.25, "drop": 0.0,
		"arm_b": [-0.75, 0.05], "arm_f": [-0.45, 0.05], "leg_b": [-0.20, -0.85], "leg_f": [1.30, 0.00]},
	"front_kick": {"lean": 0.34, "drop": 1.0,
		"arm_b": [0.48, 1.82], "arm_f": [0.35, 2.02], "leg_b": [0.58, -0.48], "leg_f": [1.64, -0.02]},
	"spinning_kick_chamber": {"lean": -0.10, "drop": 10.0,
		"arm_b": [0.48, 1.92], "arm_f": [0.36, 2.12], "leg_b": [0.30, -0.70], "leg_f": [0.82, -1.95]},
	"spinning_kick": {"lean": -0.18, "drop": 10.0,
		"arm_b": [0.48, 1.92], "arm_f": [0.36, 2.12], "leg_b": [0.30, -0.70], "leg_f": [-1.32, -0.22]},
	"spinning_kick_recoil": {"lean": -0.14, "drop": 10.0,
		"arm_b": [0.48, 1.92], "arm_f": [0.36, 2.12], "leg_b": [0.30, -0.70], "leg_f": [0.72, -1.62]},
	"spinning_kick_replant": {"lean": 0.02, "drop": 1.0,
		"arm_b": [0.42, 1.24], "arm_f": [0.18, 1.48], "leg_b": [0.28, -0.36], "leg_f": [0.20, -0.68]},
	"air_kick": {"lean": 0.08, "drop": -4.0,
		"arm_b": [0.82, 0.72], "arm_f": [-0.22, 0.15], "leg_b": [0.48, -1.10], "leg_f": [1.48, -0.18]},
	"air_rising_kick": {"lean": 0.18, "drop": -4.0,
		"arm_b": [1.10, 0.48], "arm_f": [-0.35, 0.08], "leg_b": [0.62, -1.28], "leg_f": [2.42, -0.10]},
	"air_side_kick": {"lean": 0.12, "drop": -4.0,
		"arm_b": [0.92, 0.62], "arm_f": [-0.38, 0.08], "leg_b": [0.35, -1.12], "leg_f": [1.62, 0.00]},
	"air_roundhouse": {"lean": 0.24, "drop": -4.0,
		"arm_b": [1.22, 0.40], "arm_f": [-0.72, 0.06], "leg_b": [0.72, -1.38], "leg_f": [2.05, -0.10]},
	"grab":      {"lean": -0.10, "drop": 0.0,
		"arm_b": [1.35, 0.05], "arm_f": [1.45, 0.05], "leg_b": [0.20, -0.30], "leg_f": [0.35, -0.43]},
	"boot_throw": {"lean": 0.18, "drop": 3.0,
		"arm_b": [1.12, 0.22], "arm_f": [1.34, 0.16], "leg_b": [0.42, -0.48], "leg_f": [1.55, -0.10]},
	"tomoe":     {"lean": 1.05, "drop": 15.0,
		"arm_b": [1.72, 0.35], "arm_f": [1.88, 0.28], "leg_b": [0.52, -1.05], "leg_f": [2.02, -1.02]},
	"grab_uppercut": {"lean": -0.28, "drop": -10.0,
		"arm_b": [0.62, 1.72], "arm_f": [2.78, 0.10], "leg_b": [0.62, -1.18], "leg_f": [0.98, -1.32]},
	"knee_crush": {"lean": -0.24, "drop": 10.0,
		"arm_b": [0.72, 0.55], "arm_f": [0.58, 0.42], "leg_b": [0.58, -1.02], "leg_f": [1.18, -1.32]},
	"throw":     {"lean": -0.30, "drop": 0.0,
		"arm_b": [3.20, 0.10], "arm_f": [3.10, 0.10], "leg_b": [0.65, -0.45], "leg_f": [0.35, -0.40]},
	"slam":      {"lean": 0.35, "drop": 14.0,
		"arm_b": [1.85, 0.15], "arm_f": [1.95, 0.15], "leg_b": [0.58, -1.55], "leg_f": [1.00, -1.45]},
	"hurt":      {"lean": 0.45, "drop": 0.0,
		"arm_b": [-0.95, -0.04], "arm_f": [-0.75, -0.04], "leg_b": [0.30, -0.10], "leg_f": [0.25, -0.35]},
	"hurt_head": {"lean": 0.52, "drop": 1.0,
		"arm_b": [0.10, 1.30], "arm_f": [-0.70, 0.22], "leg_b": [0.36, -0.34], "leg_f": [0.18, -0.38]},
	"hurt_body": {"lean": -0.28, "drop": 9.0,
		"arm_b": [0.78, 1.72], "arm_f": [0.68, 1.80], "leg_b": [0.58, -0.92], "leg_f": [0.72, -1.04]},
	"hurt_low":  {"lean": 0.22, "drop": 17.0,
		"arm_b": [-0.48, 0.36], "arm_f": [0.82, 0.58], "leg_b": [0.92, -1.62], "leg_f": [0.48, -1.12]},
	"hurt_launch": {"lean": -0.34, "drop": -5.0,
		"arm_b": [-1.12, 0.04], "arm_f": [-0.86, 0.04], "leg_b": [0.72, -1.20], "leg_f": [-0.20, -0.74]},
	"ko":        {"lean": 1.35, "drop": 26.0,
		"arm_b": [-1.55, -0.04], "arm_f": [-1.35, -0.04], "leg_b": [0.55, -0.30], "leg_f": [0.20, -0.35]},
}

# ---- Proportions ----
const HIP_Y      := -46.0
const TORSO_LEN  := 40.0
const HEAD_R     := 15.0
const ARM_UP     := 20.0
const ARM_LO     := 19.0
const LEG_UP     := 24.0
const LEG_LO     := 23.0
const ELBOW_MAX_FLEX := 2.70
const ELBOW_HYPEREXT := 0.06
const KNEE_MAX_FLEX := 2.55   # ~146 degres : accroupi profond, sans luxation
const KNEE_HYPEREXT := 0.035  # petite tolerance, jamais de genou inverse
const SH_W       := 30.0    # largeur epaules
const WAIST_W    := 20.0
const HIP_W      := 24.0
const PHOTO_HEAD_R := 21.0  # tete photo : plus grande, sinon le visage est illisible
const COL_SKIN   := Color(0.90, 0.76, 0.65)
# Taille du combattant 3D convertie en pixels (2,34 / 0,02).
# L'atelier normalise la trajectoire du bassin avant de l'exporter.
const ROOT_MOTION_HEIGHT_PX := 117.0

var index := 0
var prefix := "p1"
var pad_device := -1
var spawn_pos := Vector2.ZERO
var col_main := Color(0.32, 0.55, 0.95)
var col_dark := Color(0.20, 0.36, 0.68)
var base_main := Color(0.32, 0.55, 0.95)   # couleur d'origine, avant teinte photo
var base_dark := Color(0.20, 0.36, 0.68)
var display_name := ""
var draw_2d := true          # false quand un rig 3D prend le relais
var opponent: Fighter = null
var _head_img: Image = null
var _crop := Rect2()

var state: State = State.IDLE
var hp := MAX_HP
var block_energy := 1.0
var facing := 1.0
var move_name := ""

var hitbox: Area2D
var hitbox_shape: CollisionShape2D
var hurtbox: Area2D
var hurt_shape: CollisionShape2D
var hurt_head_shape: CollisionShape2D
var hurt_limb_shapes: Array[CollisionShape2D] = []
var throw_hurtbox: Area2D
var hurtbox_profile_override: Dictionary = {}
var throw_shape: CollisionShape2D
var head_sprite: Sprite2D
var sfx: AudioStreamPlayer2D

var _move: Dictionary = {}
var _attack_start_pose: Dictionary = {}
var _t := 0.0
var _phase := 0
var _still := 0.0
var _walk_cycle := 0.34
var _walk_dir_local := 0.0
var _walk_last_world_x := INF
var _flash := 0.0
var _hold := 0.0
var _escape := 0.0
var _grabbed_by: Fighter = null
var _grab_victim: Fighter = null
var _throw_pending := false
var _throw_dir := "front"
var _spin := 0.0
var _turn_y := 0.0 # rotation complete du corps autour de l'axe vertical
var _swing_a0 := 0.0            # angle du membre frappeur au moment de l'arme
var _impact_pose_t := 0.0        # garantit que l'extension est visible meme si le coup touche vite
var _buf := ""                  # action mise en attente (buffer d'entrees)
var _buf_t := 0.0
var _pose := {}
var _pose_target := "idle"
var _body_twist := Vector2.ZERO # x = bassin, y = cage thoracique (rotation 3D)
var _hook_arc := 0.0 # place le bras frappeur dans le plan horizontal du crochet
var _motion := {} # trajectoire 3D echantillonnee (appuis et coups signatures)
var _external_clip_info: Dictionary = {} # animation GLB choisie dans l'atelier
var _root_motion_last := 0.0 # deplacement Blender deja applique au corps reel
var _hit_done := false
var _active_just_started := false
var _block_stun := 0.0
var _hurt_pose_name := "hurt"
var frozen := false


func setup(p_index: int, p_spawn: Vector2, main: Color, dark: Color) -> void:
	index = p_index
	prefix = "p%d" % (index + 1)
	spawn_pos = p_spawn
	col_main = main
	col_dark = dark
	base_main = main
	base_dark = dark


func _ready() -> void:
	collision_layer = 1 << (1 + index)      # 2 ou 4
	collision_mask = 1                      # ne heurte que le sol
	var body_shape := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 16.0
	cap.height = 78.0
	body_shape.shape = cap
	body_shape.position = Vector2(0, -39)
	add_child(body_shape)

	# Hurtboxes de frappe : elles suivent la tete, le torse et les membres.
	hurtbox = Area2D.new()
	hurtbox.collision_layer = 1 << (3 + index)   # 8 ou 16
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.monitorable = true
	hurt_shape = CollisionShape2D.new()
	var hcap := CapsuleShape2D.new()
	hcap.radius = 12.0
	hcap.height = 64.0
	hurt_shape.shape = hcap
	hurtbox.add_child(hurt_shape)
	hurt_head_shape = CollisionShape2D.new()
	var head_hurt := CircleShape2D.new()
	head_hurt.radius = 14.0
	hurt_head_shape.shape = head_hurt
	hurtbox.add_child(hurt_head_shape)
	for i in 8:
		var limb_shape := CollisionShape2D.new()
		var limb_cap := CapsuleShape2D.new()
		limb_cap.radius = 6.0 if i < 4 else 7.0
		limb_cap.height = 18.0
		limb_shape.shape = limb_cap
		hurtbox.add_child(limb_shape)
		hurt_limb_shapes.append(limb_shape)
	add_child(hurtbox)

	# La saisie utilise une zone centrale stable, differente des membres.
	throw_hurtbox = Area2D.new()
	throw_hurtbox.collision_layer = 1 << (5 + index) # 32 ou 64
	throw_hurtbox.collision_mask = 0
	throw_hurtbox.monitoring = false
	throw_hurtbox.monitorable = true
	throw_shape = CollisionShape2D.new()
	var throw_cap := CapsuleShape2D.new()
	throw_cap.radius = 17.0
	throw_cap.height = 72.0
	throw_shape.shape = throw_cap
	throw_shape.position = Vector2(0, -36)
	throw_hurtbox.add_child(throw_shape)
	add_child(throw_hurtbox)

	# Hitbox : deplacee et activee par chaque attaque
	hitbox = Area2D.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = 1 << (3 + (1 - index))
	hitbox.monitoring = false
	hitbox.monitorable = false
	hitbox_shape = CollisionShape2D.new()
	hitbox_shape.shape = CircleShape2D.new()
	hitbox.add_child(hitbox_shape)
	add_child(hitbox)

	head_sprite = Sprite2D.new()
	head_sprite.material = _circle_mask()
	head_sprite.visible = false
	head_sprite.z_index = 3
	add_child(head_sprite)

	sfx = AudioStreamPlayer2D.new()
	sfx.max_distance = 2200.0
	add_child(sfx)

	_pose = _copy_pose(POSES["idle"])
	reset_round()
	_sync_hurtboxes()


# ------------------------------------------------------------
#  Boucle
# ------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if frozen or state == State.KO:
		var was_air := not is_on_floor()
		var vy := velocity.y
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		if not is_on_floor():
			velocity.y += GRAVITY * delta
			if state == State.KO:
				_spin += delta * clampf(velocity.x / 150.0, -6.0, 6.0)
		else:
			# une fois au sol, le corps se remet a plat
			_spin = move_toward(_spin, 0.0, delta * 7.0)
		move_and_slide()
		_land_fx(was_air, vy)
		_animate(delta)
		queue_redraw()
		return

	if is_instance_valid(opponent) and state in [State.IDLE, State.WALK, State.CROUCH, State.BLOCK]:
		facing = signf(opponent.global_position.x - global_position.x)
		if facing == 0.0:
			facing = 1.0

	_flash = maxf(0.0, _flash - delta * 6.0)
	_age_buffer(delta)

	match state:
		State.IDLE, State.WALK: _tick_ground(delta)
		State.CROUCH:  _tick_crouch(delta)
		State.BLOCK:   _tick_block(delta)
		State.AIR:     _tick_air(delta)
		State.ATTACK:  _tick_attack(delta)
		State.GRAB:    _tick_grab(delta)
		State.GRABBING:_tick_grabbing(delta)
		State.GRABBED: _tick_grabbed(delta)
		State.HURT:    _tick_hurt(delta)
	if not _throw_pending and state not in [State.HURT, State.KO, State.GRABBED]:
		_spin = move_toward(_spin, 0.0, delta * 8.0)

	var was_air := not is_on_floor()
	var vy := velocity.y
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	move_and_slide()
	_land_fx(was_air, vy)
	_separate()
	_animate(delta)
	queue_redraw()


func _land_fx(was_air: bool, vy_before: float) -> void:
	if was_air and is_on_floor() and vy_before > 320.0:
		Arena.dust(global_position, clampf(vy_before / 700.0, 0.3, 1.7))
		Arena.shake(clampf(vy_before / 260.0, 0.0, 7.0))


func _separate() -> void:
	# Les deux corps ne se poussent pas tout seuls : on les ecarte a la main.
	if not is_instance_valid(opponent):
		return
	var dx := global_position.x - opponent.global_position.x
	var min_d := 40.0
	if absf(dx) < min_d and absf(global_position.y - opponent.global_position.y) < 60.0:
		var push := (min_d - absf(dx)) * 0.5
		global_position.x += signf(dx if dx != 0.0 else 1.0) * push


func _dir() -> float:
	return Input.get_axis(prefix + "_left", prefix + "_right")


func _held_dir() -> bool:
	return absf(_dir()) > 0.01 \
		or Input.is_action_pressed(prefix + "_up") \
		or Input.is_action_pressed(prefix + "_down")


func _tick_ground(delta: float) -> void:
	block_energy = minf(1.0, block_energy + BLOCK_REGEN * delta)
	if _try_actions():
		return
	if _consume("jump"):
		velocity.y = JUMP_VEL
		state = State.AIR
		SFX.play2d(sfx, "jump", -10.0)
		Arena.dust(global_position, 0.35)
		return
	if Input.is_action_pressed(prefix + "_down"):
		state = State.CROUCH
		_set_crouch(true)
		_still = 0.0
		return

	var d := _dir()
	var target_speed := 0.0
	if d != 0.0:
		target_speed = d * (FORWARD_SPEED if d * facing > 0.0 else BACK_SPEED)
	velocity.x = move_toward(velocity.x, target_speed,
		(GROUND_ACCEL if d != 0.0 else GROUND_BRAKE) * delta)
	state = State.WALK if absf(velocity.x) > 2.0 else State.IDLE

	if not _held_dir():
		_still += delta
		if _still >= BLOCK_RAISE and block_energy > 0.08 \
				and AttackLibrary.has_custom_guard():
			state = State.BLOCK
	else:
		_still = 0.0


func _tick_crouch(delta: float) -> void:
	block_energy = minf(1.0, block_energy + BLOCK_REGEN * 0.5 * delta)
	velocity.x = _dir() * CROUCH_SPEED
	if _try_actions():
		return
	if not Input.is_action_pressed(prefix + "_down"):
		_set_crouch(false)
		state = State.IDLE
		_still = 0.0


func _tick_block(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
	if _block_stun > 0.0:
		_block_stun = maxf(0.0, _block_stun - delta)
		return
	block_energy -= BLOCK_DRAIN * delta
	if block_energy <= 0.0:
		block_energy = 0.0
		_hurt_pose_name = "hurt_body"
		_enter_hurt(BLOCK_BREAK, Vector2(-120 * facing, -100))
		return
	if _try_actions():
		return
	if _held_dir() or _buf == "jump":
		state = State.IDLE
		_still = 0.0


func _tick_air(delta: float) -> void:
	velocity.x = move_toward(velocity.x, _dir() * AIR_SPEED, 1500.0 * delta)
	if _try_actions():
		return
	if is_on_floor():
		state = State.IDLE
		_still = 0.0


# ------------------------------------------------------------
#  Buffer d'entrees : un appui pendant une recuperation ou un
#  hitstun n'est pas perdu, il part des que l'action redevient
#  possible. C'est ce qui fait qu'un jeu "repond".
# ------------------------------------------------------------
func _process(_delta: float) -> void:
	# La capture se fait ici, PAS dans _physics_process : pendant un hit-stop
	# le temps est a 4%, les frames physiques tombent a ~2 Hz et un appui bref
	# passerait entre deux. _process suit la cadence d'affichage.
	for a in ["punch", "kick", "grab", "jump"]:
		if Input.is_action_just_pressed(prefix + "_" + a):
			_buf = a
			_buf_t = BUFFER_TIME
			return


func _age_buffer(delta: float) -> void:
	# expiration en temps de jeu : un appui fait pendant le hit-stop
	# survit au gel et part des qu'il reprend.
	_buf_t = maxf(0.0, _buf_t - delta)
	if _buf_t <= 0.0:
		_buf = ""


func _consume(a: String) -> bool:
	if _buf == a and _buf_t > 0.0:
		_buf = ""
		_buf_t = 0.0
		return true
	return false


func _try_actions() -> bool:
	if is_on_floor() and _consume("grab"):
		_start_grab()
		return true
	if _consume("punch"):
		return _start_move(_pick("punch"))
	if _consume("kick"):
		return _start_move(_pick("kick"))
	return false


func _pick(button: String) -> String:
	var attack_dir := _attack_dir_5()
	var context := "ground" if is_on_floor() else "air"
	var fallback_move := ""
	if not is_on_floor():
		if button == "punch":
			fallback_move = {
				"up": "air_upper", "down": "air_hammer",
				"forward": "air_cross", "back": "air_backfist", "neutral": "air_punch",
			}[attack_dir]
			return AttackLibrary.move_for(context, button, attack_dir, fallback_move)
		fallback_move = {
			"up": "air_rising_kick", "down": "dive_kick",
			"forward": "air_side_kick", "back": "air_roundhouse", "neutral": "air_kick",
		}[attack_dir]
		return AttackLibrary.move_for(context, button, attack_dir, fallback_move)
	if button == "punch":
		fallback_move = {
			"up": "uppercut", "down": "body_hook",
			"forward": "hook", "back": "spinning_backfist", "neutral": "jab",
		}[attack_dir]
		return AttackLibrary.move_for(context, button, attack_dir, fallback_move)
	fallback_move = {
		"up": "high_kick", "down": "sweep",
		"forward": "front_kick", "back": "spinning_kick", "neutral": "middle_kick",
	}[attack_dir]
	return AttackLibrary.move_for(context, button, attack_dir, fallback_move)


func _attack_dir_5() -> String:
	if Input.is_action_pressed(prefix + "_up"):
		return "up"
	if Input.is_action_pressed(prefix + "_down"):
		return "down"
	var side := _dir() * facing
	if side > 0.01:
		return "forward"
	if side < -0.01:
		return "back"
	return "neutral"


# ------------------------------------------------------------
#  Attaques
# ------------------------------------------------------------
func _start_move(name_: String) -> bool:
	if not MOVES.has(name_):
		return false
	var clip_info := AttackLibrary.clip_info(name_)
	if clip_info.is_empty():
		# Aucun coup de secours : pas de GLB exporte, pas d'attaque.
		return false
	_move = AttackLibrary.apply_to_move(name_, MOVES[name_])
	move_name = name_
	_external_clip_info = clip_info
	_root_motion_last = 0.0
	_attack_start_pose = _copy_pose(_pose)
	hitbox.collision_mask = _strike_hurt_mask()
	# angle de depart du membre frappeur, avant que la pose ne bascule
	_swing_a0 = _pose[_swing_origin_key()[1]][0] * facing
	if not _is_kick():
		_swing_a0 += _pose["lean"] * facing
	state = State.ATTACK
	_phase = 0
	_t = _move["startup"]
	_impact_pose_t = 0.0
	_hit_done = false
	_active_just_started = false
	_still = 0.0
	_set_crouch(name_ in ["body_hook", "sweep"])
	if is_on_floor():
		velocity.x = 0.0
	return true


func _tick_attack(delta: float) -> void:
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 1800.0 * delta)
	_t -= delta
	# `_t +=` et non `_t =` : on reporte le reliquat de temps au lieu de le jeter.
	# Sinon chaque changement de phase gaspille une frame entiere (3 par coup).
	while _t <= 0.0:
		match _phase:
			0:
				_phase = 1
				_t += float(_move["active"])
				_impact_pose_t = maxf(_impact_pose_t, 0.045)
				_active_just_started = true
				_sync_hitbox_to_contact()
				_configure_strike_hitbox()
				hitbox.monitoring = true
				SFX.play2d(sfx, "whiff", -16.0, 0.85 if _is_kick() else 1.1)
			1:
				hitbox.monitoring = false
				_phase = 2
				_t += float(_move["recover"])
			_:
				_apply_attack_root_motion(delta, 1.0)
				_end_action()
				return

	_apply_attack_root_motion(delta, _attack_total_progress())

	if _phase == 1 and not _hit_done:
		_sync_hitbox_to_contact()
		if _active_just_started:
			# `get_overlapping_areas` ne voit pas encore la forme placee a
			# l'instant : sur la premiere frame active on interroge directement
			# l'espace physique. Sans ca un coup a 3 frames actives n'en teste
			# que 2, et il traverse l'adversaire une fois sur trois.
			_active_just_started = false
			_poll_hit_immediate()
		else:
			_poll_hit()


func _poll_hit_immediate() -> void:
	if hitbox_shape == null or hitbox_shape.shape == null:
		return
	var space := get_world_2d().direct_space_state
	if space == null:
		return
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = hitbox_shape.shape
	params.transform = hitbox.global_transform * hitbox_shape.transform
	params.collision_mask = hitbox.collision_mask
	params.collide_with_areas = true
	params.collide_with_bodies = false
	for hit in space.intersect_shape(params, 8):
		var other = (hit["collider"] as Node).get_parent()
		if other == self or not (other is Fighter):
			continue
		_hit_done = true
		_resolve(other)
		return


func _poll_hit() -> void:
	for a in hitbox.get_overlapping_areas():
		var other = a.get_parent()
		if other == self or not (other is Fighter):
			continue
		_hit_done = true
		_resolve(other)
		return


func _resolve(other: Fighter) -> void:
	var dir := signf(other.global_position.x - global_position.x)
	if dir == 0.0:
		dir = facing
	var headshot := _strike_overlaps_head(other)

	if other.state == State.BLOCK and other.facing != dir:
		# ---- GARDE > FRAPPE ----
		other.on_blocked(float(_move["dmg"]), float(_move["blockstun"]))
		hitbox.monitoring = false
		_phase = 2
		_t = float(_move["recover"])
		rumble(0.75, 0.45, 0.22)
		Arena.impact(_hitbox_world_point(),
			Vector2(-dir, -0.35), Color(0.62, 0.88, 1.0), 0.55)
		Arena.shake(3.0)
		Arena.hitstop(int(clampf(16.0 + float(_move["dmg"]) * 1.5, 20.0, 48.0)))
	elif other.state in [State.GRAB, State.GRABBING]:
		# ---- FRAPPE > GRAB ----
		other.on_hit(_move, dir, GRAB_PUNISH, _hitbox_world_point(), headshot)
		_finish_hit()
	else:
		other.on_hit(_move, dir, 0.0, _hitbox_world_point(), headshot)
		_finish_hit()


func _strike_overlaps_head(other: Fighter) -> bool:
	if not is_instance_valid(other) or hitbox_shape == null \
	or other.hurt_head_shape == null:
		return false
	other._sync_hurtboxes()
	var head_circle := other.hurt_head_shape.shape as CircleShape2D
	if head_circle == null:
		return false
	var strike_center := global_position + hitbox_shape.position
	var head_center := other.global_position + other.hurt_head_shape.position
	var delta := (head_center - strike_center).rotated(-hitbox_shape.rotation)
	var strike_shape := hitbox_shape.shape
	if strike_shape is CircleShape2D:
		return delta.length() <= (strike_shape as CircleShape2D).radius + head_circle.radius
	# Les ellipses de l'atelier sont exportees comme un polygone convexe. En
	# ajoutant le rayon de la tete aux deux axes, ce test correspond a leur
	# zone de contact sans confondre un impact au ventre avec un impact tete.
	var base_radius := float(_move.get("radius", 20.0))
	var radius_x := float(_move.get("radius_x", base_radius)) + head_circle.radius
	var radius_y := float(_move.get("radius_y", base_radius)) + head_circle.radius
	if radius_x <= 0.0 or radius_y <= 0.0:
		return false
	return delta.x * delta.x / (radius_x * radius_x) \
		+ delta.y * delta.y / (radius_y * radius_y) <= 1.0


func _finish_hit() -> void:
	hitbox.monitoring = false
	_phase = 2
	# Le mouvement conserve sa recuperation complete : raccourcir arbitrairement
	# le retour apres un impact faisait disparaitre le suivi du geste.
	_t = float(_move["recover"])
	rumble(0.20, 0.45, 0.10)


func _end_action() -> void:
	hitbox.monitoring = false
	hitbox.collision_mask = _strike_hurt_mask()
	_turn_y = 0.0
	_hook_arc = 0.0
	_motion = {}
	_external_clip_info = {}
	_root_motion_last = 0.0
	move_name = ""
	_set_crouch(false)
	state = State.AIR if not is_on_floor() else State.IDLE
	_still = 0.0


# ------------------------------------------------------------
#  Grab
# ------------------------------------------------------------
func _start_grab() -> void:
	state = State.GRAB
	hitbox.collision_mask = _throw_hurt_mask()
	_phase = 0
	_t = GRAB_STARTUP
	velocity.x = 0.0
	_still = 0.0
	_throw_pending = false


func _tick_grab(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
	_t -= delta
	while _t <= 0.0:
		match _phase:
			0:
				_phase = 1
				_t += GRAB_ACTIVE
				hitbox_shape.position = Vector2(44 * facing, -50)
				_set_hitbox_circle(24.0)
				hitbox.monitoring = true
			1:
				hitbox.monitoring = false
				hitbox.collision_mask = _strike_hurt_mask()
				# Une saisie ratee conserve sa propre pose et sa fenetre de
				# punition. Elle ne detourne plus le jab comme animation cachee.
				_phase = 2
				_t += GRAB_WHIFF
			_:
				_end_action()
				return

	if _phase == 1:
		_poll_grab()


func _poll_grab() -> void:
	for a in hitbox.get_overlapping_areas():
		var other = a.get_parent()
		if other == self or not (other is Fighter):
			continue
		if other.state in [State.GRABBED, State.KO]:
			continue
		hitbox.monitoring = false
		# ---- GRAB > GARDE ----
		if other.state == State.BLOCK:
			other.block_energy = 0.0
		other._on_grabbed(self)
		_grab_victim = other
		state = State.GRABBING
		_hold = GRAB_HOLD
		rumble(0.35, 0.35, 0.14)
		SFX.play2d(sfx, "grab", -6.0)
		return


func _tick_grabbing(delta: float) -> void:
	velocity.x = 0.0
	if not is_instance_valid(_grab_victim) or _grab_victim.state != State.GRABBED:
		_throw_pending = false
		_release()
		return
	_grab_victim.global_position.x = global_position.x + 42.0 * facing
	_grab_victim.global_position.y = global_position.y

	if _throw_pending:
		_t -= delta
		_choreograph_throw()
		if _t <= 0.0:
			_throw_pending = false
			_throw()
		return

	_hold -= delta
	# une direction pressee projette immediatement de ce cote...
	var tapped := _throw_dir_just_pressed()
	if tapped != "":
		_begin_throw(tapped)
	# ...sinon un bouton (ou la fin du temps de prise) projette dans la direction tenue.
	# On consomme le buffer : sinon l'appui repartirait en coup juste apres la projection.
	elif _consume("punch") or _consume("kick") or _consume("grab") or _hold <= 0.0:
		_begin_throw(_throw_dir_held())


func _throw_dir_just_pressed() -> String:
	if Input.is_action_just_pressed(prefix + "_up"):
		return "up"
	if Input.is_action_just_pressed(prefix + "_down"):
		return "down"
	if Input.is_action_just_pressed(prefix + "_left"):
		return "back" if facing > 0.0 else "front"
	if Input.is_action_just_pressed(prefix + "_right"):
		return "front" if facing > 0.0 else "back"
	return ""


func _throw_dir_held() -> String:
	if Input.is_action_pressed(prefix + "_up"):
		return "up"
	if Input.is_action_pressed(prefix + "_down"):
		return "down"
	if _dir() * facing < -0.01:
		return "back"
	return "front"


func _begin_throw(dir_name: String) -> void:
	# petit temps d'elan avant le relachement -> lisible comme une vraie projection
	_throw_dir = dir_name
	_throw_pending = true
	_t = THROW_RELEASE


func _choreograph_throw() -> void:
	# La victime suit le geste pendant l'elan : chaque projection doit etre
	# identifiable avant meme le knockback final.
	if not is_instance_valid(_grab_victim):
		return
	var p := smoothstep(0.0, 1.0, clampf(1.0 - _t / THROW_RELEASE, 0.0, 1.0))
	match _throw_dir:
		"front":
			# La victime est tournee dans le meme sens : son bassin est clairement
			# presente au pied avant d'etre projetee vers l'avant.
			_grab_victim.facing = facing
			_grab_victim.global_position = global_position + Vector2(lerpf(46.0, 64.0, p) * facing, 0)
			_grab_victim._spin = -0.10 * facing * p
		"back":
			# Tomoe-nage : chute arriere, pied au ventre, adversaire au-dessus.
			_spin = -1.02 * facing * p
			_grab_victim.global_position = global_position + Vector2(lerpf(38.0, -4.0, p) * facing, -52.0 * p)
			_grab_victim._spin = 1.65 * facing * p
		"up":
			_grab_victim.global_position = global_position + Vector2(lerpf(40.0, 28.0, p) * facing, -20.0 * p)
			_grab_victim._spin = -0.16 * facing * p
		"down":
			# La tete est tiree vers le genou qui remonte.
			# Le bassin passe derriere l'attaquant : avec la rotation du torse,
			# c'est bien la tete (et non les jambes) qui arrive sur le genou.
			_grab_victim.global_position = global_position + Vector2(lerpf(40.0, -65.0, p) * facing, -4.0 * p)
			_grab_victim._spin = 0.92 * facing * p


func _throw() -> void:
	var v := _grab_victim
	var thrown_dir := _throw_dir
	var t: Dictionary = THROWS.get(_throw_dir, THROWS["front"])
	_grab_victim = null
	if is_instance_valid(v):
		v._grabbed_by = null
		v._hurt_pose_name = "hurt_launch" if thrown_dir in ["back", "up"] \
			else ("hurt_body" if thrown_dir == "down" else "hurt_head")
		var kb: Vector2 = t["kb"]
		kb.x *= facing
		if thrown_dir == "back":
			v.global_position = global_position + Vector2(-38.0 * facing, -34.0)
		elif thrown_dir == "down":
			v.global_position.y -= 24.0
		v.take_damage(THROW_DAMAGE * float(t["dmg"]), kb, float(t["stun"]))
		var power: float = 1.9 if thrown_dir in ["down", "back"] else 1.5
		var impact_pos := v.global_position + Vector2(0, -46)
		if thrown_dir == "down":
			impact_pos = global_position + Vector2(24.0 * facing, -48.0)
		elif thrown_dir == "up":
			impact_pos = global_position + Vector2(28.0 * facing, -82.0)
		Arena.impact(impact_pos, kb.normalized(),
			Color(1.0, 0.85, 0.4), power)
		Arena.shake(15.0 if thrown_dir in ["down", "back"] else 10.0)
		Arena.hitstop(140 if thrown_dir in ["down", "back"] else 105)
		SFX.play2d(sfx, "throw", -3.0)
	if thrown_dir == "up":
		velocity.y = -460.0
		state = State.AIR
	else:
		state = State.IDLE
	_still = 0.0
	_throw_dir = "front"


func _free_victim() -> void:
	# Detache la victime sans toucher a mon propre etat.
	if is_instance_valid(_grab_victim) and _grab_victim.state == State.GRABBED:
		_grab_victim._grabbed_by = null
		_grab_victim.state = State.IDLE
	_grab_victim = null
	_throw_pending = false


func _release() -> void:
	_free_victim()
	state = State.IDLE
	_still = 0.0


func _on_grabbed(by: Fighter) -> void:
	state = State.GRABBED
	_grabbed_by = by
	_escape = 0.0
	velocity = Vector2.ZERO
	hitbox.monitoring = false


func _tick_grabbed(delta: float) -> void:
	velocity = Vector2.ZERO
	_escape = maxf(0.0, _escape - ESCAPE_DECAY * delta)
	if Input.is_action_just_pressed(prefix + "_punch") \
	or Input.is_action_just_pressed(prefix + "_kick") \
	or Input.is_action_just_pressed(prefix + "_grab") \
	or Input.is_action_just_pressed(prefix + "_jump"):
		_escape += 1.0
	if _escape >= ESCAPE_NEEDED and is_instance_valid(_grabbed_by):
		var g := _grabbed_by
		g._free_victim()        # me detache et me repasse en IDLE
		g._enter_hurt(0.40, Vector2(-200 * g.facing, -120))


func _tick_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
	if not is_on_floor():
		_spin += delta * clampf(velocity.x / 150.0, -6.0, 6.0)
	else:
		_spin = move_toward(_spin, 0.0, delta * 7.0)
	_t -= delta
	if _t <= 0.0 and is_on_floor():
		state = State.IDLE
		_still = 0.0
		_spin = 0.0
		block_energy = maxf(block_energy, 0.2)


# ------------------------------------------------------------
#  Degats
# ------------------------------------------------------------
func on_blocked(dmg: float, stun := 0.16) -> void:
	block_energy = maxf(0.0, block_energy - dmg * GUARD_DRAIN)
	hp = maxf(0.0, hp - dmg * CHIP_RATIO)
	state = State.BLOCK
	_block_stun = maxf(_block_stun, stun)
	hp_changed.emit()
	velocity.x = -facing * (BLOCK_PUSH_BASE + dmg * BLOCK_PUSH_PER_DMG)
	rumble(0.35, 0.10, 0.12)
	SFX.play2d(sfx, "block", -8.0)
	if hp <= 0.0:
		_die()


func on_hit(mv: Dictionary, dir: float, extra_stun: float,
		impact_at := Vector2.INF, headshot := false) -> void:
	var kb: Vector2 = mv["kb"]
	var dmg: float = float(mv["dmg"]) * (HEAD_DAMAGE_MULTIPLIER if headshot else 1.0)
	var box: Vector2 = mv.get("box", Vector2(0, -50))
	if kb.y < -360.0:
		_hurt_pose_name = "hurt_launch"
	elif headshot or box.y <= -70.0:
		_hurt_pose_name = "hurt_head"
	elif box.y >= -28.0:
		_hurt_pose_name = "hurt_low"
	else:
		_hurt_pose_name = "hurt_body"
	take_damage(dmg, Vector2(kb.x * dir, kb.y), float(mv["hitstun"]) + extra_stun)
	var at: Vector2 = impact_at
	if not at.is_finite():
		at = global_position + Vector2(kb.x * dir, kb.y).normalized() * 14.0 + Vector2(0, -50)
	var impact_color := Color(1.0, 0.48, 0.24) if headshot else Color(1.0, 0.78, 0.38)
	Arena.impact(at, Vector2(kb.x * dir, kb.y), impact_color, dmg / 9.0)
	Arena.shake(2.0 + dmg * 0.45)
	Arena.hitstop(int(clampf(24.0 + dmg * 2.6, 24.0, 105.0)))
	SFX.play2d(sfx, "hit_heavy" if dmg >= 12.0 else "hit_light", -4.0)


func take_damage(amount: float, kb: Vector2, stun: float) -> void:
	if state == State.KO:
		return
	hp = maxf(0.0, hp - amount)
	hp_changed.emit()
	_flash = 0.85          # pas 1.0 : on garde un reste de couleur pour lire la silhouette
	rumble(0.45, 0.85, 0.20)
	if hp <= 0.0:
		velocity = Vector2(kb.x * 1.4, -420.0)
		_die()
		return
	_enter_hurt(stun, kb)


func _enter_hurt(stun: float, kb: Vector2) -> void:
	if is_instance_valid(_grabbed_by):
		_grabbed_by._free_victim()
	_free_victim()          # si j'etais le saisisseur, je lache aussi
	hitbox.monitoring = false
	_set_crouch(false)
	state = State.HURT
	_t = stun
	velocity = kb
	_external_clip_info = {}
	_root_motion_last = 0.0
	move_name = ""


func _die() -> void:
	if is_instance_valid(_grabbed_by):
		_grabbed_by._free_victim()
	_free_victim()
	hitbox.monitoring = false
	_set_crouch(false)
	state = State.KO
	_external_clip_info = {}
	_root_motion_last = 0.0
	move_name = ""
	Arena.shake(16.0)
	Arena.hitstop(180)
	SFX.play2d(sfx, "ko", -2.0)
	ko.emit()


func reset_round() -> void:
	hp = MAX_HP
	block_energy = 1.0
	state = State.IDLE
	velocity = Vector2.ZERO
	global_position = spawn_pos
	_t = 0.0
	_phase = 0
	_still = 0.0
	_flash = 0.0
	_grabbed_by = null
	_grab_victim = null
	_throw_pending = false
	_spin = 0.0
	_turn_y = 0.0
	_body_twist = Vector2.ZERO
	_hook_arc = 0.0
	_motion = {}
	_external_clip_info = {}
	_root_motion_last = 0.0
	_attack_start_pose = {}
	_impact_pose_t = 0.0
	_active_just_started = false
	_block_stun = 0.0
	_hurt_pose_name = "hurt"
	_walk_cycle = 0.34
	_walk_dir_local = 0.0
	_walk_last_world_x = INF
	_buf = ""
	_buf_t = 0.0
	move_name = ""
	frozen = false
	_set_crouch(false)
	hitbox.monitoring = false
	hp_changed.emit()


func _set_crouch(on: bool) -> void:
	# Les hurtboxes de frappe suivent maintenant le squelette. Seule la zone
	# centrale de saisie reste volontairement stable et compacte.
	if on:
		throw_shape.shape.height = 48.0
		throw_shape.position = Vector2(0, -24)
	else:
		throw_shape.shape.height = 72.0
		throw_shape.position = Vector2(0, -36)


func _strike_hurt_mask() -> int:
	return 1 << (3 + (1 - index))


func _throw_hurt_mask() -> int:
	return 1 << (5 + (1 - index))


func _fit_hurt_segment(node: CollisionShape2D, a: Vector2, b: Vector2, radius: float) -> void:
	var cap := node.shape as CapsuleShape2D
	if cap == null:
		return
	var d := b - a
	node.position = (a + b) * 0.5
	node.rotation = d.angle() - PI * 0.5
	cap.radius = radius
	cap.height = maxf(radius * 2.0, d.length() + radius * 2.0)


func _body_point(p: Vector2, hip: Vector2) -> Vector2:
	return hip + (p - hip).rotated(_spin)


func _sync_hurtboxes() -> void:
	if hurt_shape == null or hurt_head_shape == null or hurt_limb_shapes.size() < 8:
		return
	var hip := _hip()
	var sh := _shoulder()
	var head := _head_pos()
	var arm_b := _joints(sh, _pose["arm_b"], ARM_UP, ARM_LO)
	var arm_f := _joints(sh, _pose["arm_f"], ARM_UP, ARM_LO)
	var leg_b := _leg_joints(hip, _pose["leg_b"])
	var leg_f := _leg_joints(hip, _pose["leg_f"])
	var profile_context := "neutral"
	if state == State.BLOCK:
		profile_context = "guard"
	elif state == State.CROUCH:
		profile_context = "crouch"
	elif state == State.ATTACK:
		profile_context = "move"
	var profile := hurtbox_profile_override if not hurtbox_profile_override.is_empty() \
		else AttackLibrary.hurtbox_profile(profile_context, move_name)
	var arm_scale := clampf(float(profile.get("arms_scale", 1.0)), 0.25, 2.0)
	var leg_scale := clampf(float(profile.get("legs_scale", 1.0)), 0.25, 2.0)
	var raw_segments := [
		[sh, arm_b[0], 6.5 * arm_scale], [arm_b[0], arm_b[1], 5.5 * arm_scale],
		[sh, arm_f[0], 6.5 * arm_scale], [arm_f[0], arm_f[1], 5.5 * arm_scale],
		[hip, leg_b[0], 8.0 * leg_scale], [leg_b[0], leg_b[1], 6.5 * leg_scale],
		[hip, leg_f[0], 8.0 * leg_scale], [leg_f[0], leg_f[1], 6.5 * leg_scale],
	]
	var hip_r := _body_point(hip, hip)
	var sh_r := _body_point(sh, hip)
	# L'accroupissement est une vraie esquive des attaques hautes. Le rendu 3D
	# peut utiliser une pose personnalisee, tandis que cette correction garde
	# les zones de reception nettement sous la hauteur d'un coup a la tete.
	var crouch_drop := Vector2(0.0, 38.0) if state == State.CROUCH else Vector2.ZERO
	hip_r += crouch_drop
	sh_r += crouch_drop
	var torso_offset := Vector2(
		float(profile.get("torso_x", 0.0)) * facing,
		float(profile.get("torso_y", 0.0)))
	var torso_center := (hip_r + sh_r) * 0.5 + torso_offset
	var torso_half := (sh_r - hip_r) * 0.5 \
		* clampf(float(profile.get("torso_length", 1.0)), 0.35, 1.8)
	_fit_hurt_segment(hurt_shape, torso_center - torso_half,
		torso_center + torso_half, clampf(float(profile.get("torso_radius", 12.0)), 4.0, 28.0))
	var head_circle := hurt_head_shape.shape as CircleShape2D
	if head_circle != null:
		head_circle.radius = clampf(float(profile.get("head_radius", 14.0)), 4.0, 32.0)
	hurt_head_shape.position = _body_point(head, hip) + crouch_drop + Vector2(
		float(profile.get("head_x", 0.0)) * facing,
		float(profile.get("head_y", 0.0)))
	for i in raw_segments.size():
		var s: Array = raw_segments[i]
		var segment_drop := crouch_drop if i < 4 else Vector2.ZERO
		_fit_hurt_segment(hurt_limb_shapes[i], _body_point(s[0], hip) + segment_drop,
			_body_point(s[1], hip) + segment_drop, float(s[2]))


func _sync_hitbox_to_contact() -> void:
	if _move.is_empty() or hitbox_shape == null:
		return
	var point := _strike_point()
	var authored: Vector2 = _move.get("box", Vector2(42, -50))
	authored.x *= facing
	# Une zone enregistree depuis l'atelier visuel est volontairement exacte.
	# Elle ne doit plus etre remelangee avec la main ou le pied automatique.
	if bool(_move.get("hitbox_authored", false)):
		hitbox_shape.position = authored
		return
	# Les coups retournes ont un membre local dirige vers l'arriere, puis remis
	# vers l'adversaire par la rotation 3D. On projette cette rotation avant de
	# positionner la collision.
	if move_name in ["spinning_kick", "spinning_backfist"]:
		point.x *= cos(_turn_y)
		point = point.lerp(authored, 0.55)
	elif move_name in ["hook", "body_hook"]:
		# Le crochet quitte le plan 2D : le marqueur auteur fixe son niveau final,
		# tandis que le poignet garde une influence sur la portee.
		point = point.lerp(authored, 0.70)
	hitbox_shape.position = point


func _configure_strike_hitbox() -> void:
	if _move.is_empty() or hitbox_shape == null:
		return
	var base_radius := float(_move.get("radius", 20.0))
	var radius_x := clampf(float(_move.get("radius_x", base_radius)), 5.0, 100.0)
	var radius_y := clampf(float(_move.get("radius_y", base_radius)), 5.0, 100.0)
	var shape_name := str(_move.get("hitbox_shape", "circle"))
	if shape_name != "ellipse":
		_set_hitbox_circle(base_radius)
		return
	var ellipse := ConvexPolygonShape2D.new()
	var points := PackedVector2Array()
	for index in 32:
		var angle := TAU * float(index) / 32.0
		points.append(Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	ellipse.points = points
	hitbox_shape.shape = ellipse
	hitbox_shape.rotation = deg_to_rad(float(_move.get("hitbox_rotation", 0.0))) * facing


func _set_hitbox_circle(radius: float) -> void:
	var circle := CircleShape2D.new()
	circle.radius = clampf(radius, 5.0, 100.0)
	hitbox_shape.shape = circle
	hitbox_shape.rotation = 0.0


func rumble(weak: float, strong: float, dur: float) -> void:
	if pad_device >= 0:
		Input.start_joy_vibration(pad_device, weak, strong, dur)


# ------------------------------------------------------------
#  Animation : on interpole vers la pose cible
# ------------------------------------------------------------
func _animate(delta: float) -> void:
	_motion = {}
	match state:
		State.KO:      _pose_target = "ko"
		State.HURT:    _pose_target = _hurt_pose_name
		State.BLOCK:   _pose_target = "block"
		State.CROUCH:  _pose_target = "crouch"
		State.AIR:     _pose_target = "air"
		State.GRAB:    _pose_target = "grab"
		State.GRABBING:
			if _throw_pending:
				_pose_target = str(THROWS.get(_throw_dir, THROWS["front"])["pose"])
			else:
				_pose_target = "grab"
		State.GRABBED: _pose_target = "hurt"
		State.ATTACK:  _pose_target = _move.get("pose", "idle")
		State.WALK:    _pose_target = "walk"
		_:             _pose_target = "idle"

	var tgt: Dictionary = POSES[_pose_target]
	var speed := 15.0
	var twist_tgt := Vector2.ZERO
	var turn_tgt := 0.0
	var hook_tgt := 0.0
	if state == State.WALK:
		speed = 24.0
		tgt = _walk_pose(delta)
	else:
		_walk_last_world_x = INF
		_walk_dir_local = 0.0
	if state == State.ATTACK:
		tgt = _attack_timeline_pose()
		_motion = CombatMotion.sample_attack(move_name, _attack_total_progress())
		var channels := _attack_timeline_channels()
		twist_tgt = channels["twist"]
		turn_tgt = channels["turn"]
		hook_tgt = channels["hook"]
		# Les clips captures separent le depart du bassin de celui de la cage.
		# Ils remplacent les canaux generiques uniquement lorsqu'ils les publient.
		if _motion.has("hip") and _motion.has("chest"):
			twist_tgt = Vector2(float(_motion["hip"]), float(_motion["chest"]))
		if _motion.has("turn"):
			turn_tgt = float(_motion["turn"]) * facing
	elif _throw_pending:
		speed = 42.0
		twist_tgt = Vector2(0.34, 0.58)
	elif state in [State.GRAB, State.GRABBING]:
		twist_tgt = Vector2(0.08, 0.18)
	_impact_pose_t = maxf(0.0, _impact_pose_t - delta)

	if state == State.ATTACK:
		# Les canaux sont echantillonnes sur la meme horloge que les phases de
		# combat. Le membre, le bassin et la cage atteignent donc le contact ensemble.
		_body_twist = twist_tgt
		_turn_y = turn_tgt
		_hook_arc = hook_tgt
		_pose = _copy_pose(tgt)
	else:
		_body_twist = _body_twist.lerp(twist_tgt, minf(1.0, 15.0 * delta))
		_turn_y = lerpf(_turn_y, turn_tgt, minf(1.0, 18.0 * delta))
		_hook_arc = lerpf(_hook_arc, hook_tgt, minf(1.0, 22.0 * delta))
		_pose["lean"] = lerpf(_pose["lean"], tgt["lean"], minf(1.0, speed * delta))
		_pose["drop"] = lerpf(_pose["drop"], tgt["drop"], minf(1.0, speed * delta))
		for k in ["arm_b", "arm_f", "leg_b", "leg_f"]:
			for i in 2:
				_pose[k][i] = lerpf(_pose[k][i], tgt[k][i], minf(1.0, speed * delta))
		if state == State.WALK:
			# Ne pas lisser les pieds : leur vitesse locale annule exactement celle
			# du corps pendant l'appui, ce qui supprime le patinage.
			_pose["leg_f"] = [tgt["leg_f"][0], tgt["leg_f"][1]]
			_pose["leg_b"] = [tgt["leg_b"][0], tgt["leg_b"][1]]

	# Filet de securite anatomique. Meme pendant une interpolation rapide ou
	# apres l'ajout d'une future pose, un tibia ne peut pas traverser le genou.
	for k in ["arm_b", "arm_f"]:
		_pose[k][1] = clampf(_pose[k][1], -ELBOW_HYPEREXT, ELBOW_MAX_FLEX)
	for k in ["leg_b", "leg_f"]:
		_pose[k][1] = clampf(_pose[k][1], -KNEE_MAX_FLEX, KNEE_HYPEREXT)
	_sync_hurtboxes()
	if hitbox.monitoring and state == State.ATTACK:
		_sync_hitbox_to_contact()

	if has_photo() and draw_2d:
		head_sprite.visible = true
		# la tete importee doit suivre la meme rotation autour du bassin que le corps
		var piv := _hip()
		head_sprite.position = piv + (_head_pos() - piv).rotated(_spin)
		head_sprite.rotation = _pose["lean"] * facing + _spin


func _walk_pose(_delta: float) -> Dictionary:
	var p := _copy_pose(POSES["walk"])
	# Le deplacement ne possede pas de geste de bras impose. En l'absence d'un
	# modele 3D personnalise, il conserve donc les bras de la position vulnerable.
	# Les jambes restent pilotees independamment par le cycle de pas ci-dessous.
	var vulnerable: Dictionary = POSES["idle"]
	p["arm_f"] = [vulnerable["arm_f"][0], vulnerable["arm_f"][1]]
	p["arm_b"] = [vulnerable["arm_b"][0], vulnerable["arm_b"][1]]
	var local_dir := signf(velocity.x * facing)
	if local_dir == 0.0:
		local_dir = _walk_dir_local if _walk_dir_local != 0.0 else 1.0
	if _walk_dir_local != 0.0 and local_dir != _walk_dir_local:
		# Conserve la position des pieds lors d'un changement de sens.
		_walk_cycle = fposmod(0.5 - _walk_cycle, 1.0)
	_walk_dir_local = local_dir
	if not is_finite(_walk_last_world_x):
		_walk_last_world_x = global_position.x
	var travelled := absf(global_position.x - _walk_last_world_x)
	_walk_last_world_x = global_position.x
	var step_len := 48.0 if local_dir > 0.0 else 40.0
	var lift := 5.5 if local_dir > 0.0 else 4.0
	_walk_cycle = fposmod(_walk_cycle + travelled / (step_len * 2.0), 1.0)
	_motion = CombatMotion.sample_gait(_walk_cycle, local_dir)
	var front := _gait_foot(_walk_cycle, local_dir, step_len, lift)
	var back := _gait_foot(fposmod(_walk_cycle + 0.5, 1.0), local_dir, step_len, lift)
	# Le bassin reste legerement flechi : une jambe d'appui peut ainsi toucher
	# le tapis avec une vraie largeur de stance, sans extension impossible.
	var bob := 4.0 + float(_motion.get("drop", 0.0)) * 0.35
	p["lean"] = 0.055 if local_dir > 0.0 else -0.015
	p["drop"] = bob
	var hip_to_floor := -HIP_Y - bob
	p["leg_f"] = _leg_ik(Vector2(front.x, hip_to_floor - front.y))
	p["leg_b"] = _leg_ik(Vector2(back.x, hip_to_floor - back.y))
	return p


func _gait_foot(q: float, local_dir: float, step_len: float, lift: float) -> Vector2:
	var half := step_len * 0.5
	if q < 0.5:
		# Appui : le pied recule localement d'exactement une longueur de pas.
		return Vector2(lerpf(half, -half, q * 2.0) * local_dir, 0.0)
	var u := (q - 0.5) * 2.0
	var travel := smoothstep(0.0, 1.0, u)
	return Vector2(lerpf(-half, half, travel) * local_dir, sin(u * PI) * lift)


func _move_phase_progress() -> float:
	var key := "startup" if _phase == 0 else ("active" if _phase == 1 else "recover")
	var duration := maxf(float(_move.get(key, 0.01)), 0.001)
	return clampf(1.0 - _t / duration, 0.0, 1.0)


func _attack_total_progress() -> float:
	if _move.is_empty():
		return 0.0
	var startup := float(_move["startup"])
	var active := float(_move["active"])
	var recover := float(_move["recover"])
	var elapsed := 0.0
	match _phase:
		0: elapsed = startup * _move_phase_progress()
		1: elapsed = startup + active * _move_phase_progress()
		_: elapsed = startup + active + recover * _move_phase_progress()
	return clampf(elapsed / maxf(startup + active + recover, 0.001), 0.0, 1.0)


func _root_motion_at(progress: float) -> float:
	var curve = _external_clip_info.get("root_motion_curve", [])
	if not (curve is Array) or curve.size() < 2:
		return 0.0
	var q := clampf(progress, 0.0, 1.0)
	var previous = curve[0]
	if not (previous is Array) or previous.size() < 2:
		return 0.0
	for index in range(1, curve.size()):
		var following = curve[index]
		if not (following is Array) or following.size() < 2:
			continue
		var t0 := float(previous[0])
		var t1 := float(following[0])
		if q <= t1:
			var blend := clampf((q - t0) / maxf(t1 - t0, 0.0001), 0.0, 1.0)
			return lerpf(float(previous[1]), float(following[1]), blend)
		previous = following
	return float(previous[1])


func _apply_attack_root_motion(delta: float, progress: float) -> void:
	var curve = _external_clip_info.get("root_motion_curve", [])
	if not (curve is Array) or curve.size() < 2 or not is_on_floor():
		return
	var wanted := clampf(_root_motion_at(progress), -1.5, 1.5)
	var step := (wanted - _root_motion_last) * ROOT_MOTION_HEIGHT_PX * facing
	_root_motion_last = wanted
	velocity.x = step / maxf(delta, 0.0001)


func _recovery_base_pose() -> Dictionary:
	if move_name in ["body_hook", "sweep"]:
		return POSES["crouch"]
	if move_name in AIR_MOVE_NAMES:
		return POSES["air"]
	return POSES["idle"]


func _attack_timeline_pose() -> Dictionary:
	var q := _move_phase_progress()
	var start_pose := _attack_start_pose if not _attack_start_pose.is_empty() else POSES["idle"]
	var impact: Dictionary = POSES[_pose_target]
	var recovery := _recovery_base_pose()
	if move_name == "spinning_kick":
		if _phase == 0:
			# Genou serre pendant le debut du pivot, puis extension pendant que
			# le corps continue de tourner : une seule acceleration lisible.
			if q < 0.34:
				return _pose_lerp(start_pose, POSES["spinning_kick_chamber"],
					smoothstep(0.0, 0.34, q))
			return _pose_lerp(POSES["spinning_kick_chamber"], impact,
				smoothstep(0.34, 1.0, q))
		if _phase == 1:
			return impact
		if q < 0.32:
			return _pose_lerp(impact, POSES["spinning_kick_recoil"], smoothstep(0.0, 0.32, q))
		if q < 0.62:
			return _pose_lerp(POSES["spinning_kick_recoil"], POSES["spinning_kick_replant"],
				smoothstep(0.32, 0.62, q))
		return _pose_lerp(POSES["spinning_kick_replant"], recovery, smoothstep(0.62, 1.0, q))

	var chamber := _attack_phase_pose(0)
	if _phase == 0:
		if q < 0.38:
			return _pose_lerp(start_pose, chamber, smoothstep(0.0, 0.38, q))
		return _pose_lerp(chamber, impact, smoothstep(0.38, 1.0, q))
	if _phase == 1:
		return impact
	return _pose_lerp(impact, recovery, smoothstep(0.0, 1.0, q))


func _attack_timeline_channels() -> Dictionary:
	var q := _move_phase_progress()
	var turn := 0.0
	var twist := Vector2.ZERO
	var hook := 0.0
	if move_name == "spinning_kick":
		if _phase == 0:
			if q < 0.34:
				turn = lerpf(0.0, 0.58, smoothstep(0.0, 0.34, q))
				twist = _attack_twist(lerpf(0.0, -0.35, smoothstep(0.0, 0.34, q)))
			else:
				turn = lerpf(0.58, 3.28, smoothstep(0.34, 1.0, q))
				twist = _attack_twist(lerpf(-0.35, 1.0, smoothstep(0.34, 1.0, q)))
		elif _phase == 1:
			turn = lerpf(3.28, 3.52, smoothstep(0.0, 1.0, q))
			twist = _attack_twist(1.0)
		else:
			turn = lerpf(3.52, TAU, smoothstep(0.0, 1.0, q))
			twist = _attack_twist(1.0 - smoothstep(0.12, 0.86, q))
		return {"turn": turn * facing, "twist": twist, "hook": 0.0}

	if move_name == "spinning_backfist":
		if _phase == 0:
			turn = lerpf(0.0, 3.30, smoothstep(0.0, 1.0, q))
			twist = _attack_twist(smoothstep(0.22, 1.0, q))
		elif _phase == 1:
			turn = lerpf(3.30, 3.48, q)
			twist = _attack_twist(1.0)
		else:
			turn = lerpf(3.48, TAU, smoothstep(0.0, 1.0, q))
			twist = _attack_twist(1.0 - q)
		return {"turn": turn * facing, "twist": twist, "hook": 0.0}

	var amount := _attack_yaw_amount()
	if _phase == 0:
		if q < 0.38:
			var load := smoothstep(0.0, 0.38, q)
			turn = lerpf(0.0, -amount * 0.26, load)
			twist = _attack_twist(-0.35 * load)
		else:
			var drive := smoothstep(0.38, 1.0, q)
			turn = lerpf(-amount * 0.26, amount, drive)
			twist = _attack_twist(lerpf(-0.35, 1.0, drive))
	elif _phase == 1:
		turn = lerpf(amount, amount * 1.06, q)
		twist = _attack_twist(1.0)
	else:
		turn = lerpf(amount * 1.06, 0.0, smoothstep(0.0, 1.0, q))
		twist = _attack_twist(1.0 - smoothstep(0.0, 0.82, q))
	if move_name in ["hook", "body_hook"]:
		if _phase == 0:
			hook = smoothstep(0.45, 1.0, q)
		elif _phase == 1:
			hook = 1.0
		else:
			hook = 1.0 - smoothstep(0.0, 0.55, q)
	return {"turn": turn * facing, "twist": twist, "hook": hook}


func _attack_phase_pose(anim_phase: int) -> Dictionary:
	# Une attaque ne saute plus directement de la garde a l'extension maximale.
	# Startup = membre arme, active = pose de frappe, recovery = retour en appui.
	if anim_phase == 1:
		return POSES[_pose_target]
	var base_name := "idle"
	if move_name in ["body_hook", "sweep"]:
		base_name = "crouch"
	elif move_name in AIR_MOVE_NAMES:
		base_name = "air"
	var p := _copy_pose(POSES[base_name])
	if anim_phase >= 2:
		return p

	if _is_kick():
		# Chamber : le genou monte avant que le tibia ne se detende.
		p["lean"] = 0.22 if move_name in ["high_kick", "air_rising_kick"] else 0.12
		if move_name == "sweep":
			p["lean"] = -0.04
			p["leg_f"] = [0.48, -1.55]
		elif move_name == "dive_kick":
			p["lean"] = -0.18
			p["leg_f"] = [0.38, -1.38]
		elif move_name == "spinning_kick":
			# Le buste plonge deja sur la jambe d'appui pendant l'armement.
			p["lean"] = -0.24
			p["leg_f"] = [-0.58, -1.22]
		elif move_name == "front_kick":
			# Chasse : genou serre devant le torse, talon encore replie.
			p["lean"] = 0.28
			p["leg_f"] = [1.06, -1.78]
		elif move_name == "middle_kick":
			# Middle : la hanche s'ouvre sur le cote avant le fouette.
			p["lean"] = 0.04
			p["leg_f"] = [0.68, -1.22]
		else:
			p["leg_f"] = [0.82, -1.42]
		p["arm_b"] = [0.82, 0.72]
		p["arm_f"] = [-0.25, 0.18]
	else:
		# Le poing reste pres du menton pendant que l'epaule recule.
		p["arm_f"] = [0.02, 2.24]
		if move_name == "uppercut":
			p["arm_f"] = [0.34, 2.32]
		elif move_name == "hook":
			# Depart depuis la garde, sans telegraphier en envoyant la main
			# derriere le corps. L'arc horizontal est construit par le rig 3D.
			p["lean"] = 0.02
			p["arm_f"] = [0.28, 2.02]
		elif move_name == "body_hook":
			# Les genoux placent l'epaule au niveau du corps ; le poing reste
			# pres de la garde jusqu'au declenchement.
			p["lean"] = -0.16
			p["drop"] = 12.0
			p["arm_f"] = [0.34, 1.92]
		elif move_name == "spinning_backfist":
			# Le dos et le bras s'arment du cote oppose avant de revenir.
			p["lean"] = 0.18
			p["arm_b"] = [0.72, 1.30]
			p["arm_f"] = [-0.68, 0.06]
	return p


func _attack_twist(direction: float) -> Vector2:
	# Le bassin initie les kicks ; la cage thoracique initie les poings.
	if _is_kick():
		if move_name in ["spinning_kick", "air_roundhouse"]:
			return Vector2(0.98, -0.42) * direction
		if move_name == "sweep":
			return Vector2(0.92, -0.34) * direction
		if move_name in ["middle_kick", "high_kick"]:
			return Vector2(0.78, -0.28) * direction
		if move_name == "front_kick":
			return Vector2(0.38, -0.12) * direction
		return Vector2(0.58, -0.20) * direction
	if move_name in ["spinning_backfist", "air_backfist"]:
		return Vector2(0.42, 1.08) * direction
	if move_name == "jab":
		return Vector2(0.08, 0.22) * direction
	if move_name in ["hook", "body_hook"]:
		return Vector2(0.36, 0.62) * direction
	if move_name == "uppercut":
		return Vector2(0.30, 0.72) * direction
	return Vector2(0.24, 0.58) * direction


func _attack_yaw_amount() -> float:
	# Rotation verticale visible de l'ensemble du combattant a l'impact.
	# Les valeurs restent sous un demi-tour, sauf pour les coups retournes.
	match move_name:
		"jab": return 0.12
		"hook": return 0.55
		"body_hook": return 0.50
		"uppercut": return 0.34
		"middle_kick": return 0.72
		"high_kick": return 0.78
		"sweep": return 0.92
		"front_kick": return 0.28
		"air_punch": return 0.22
		"air_kick": return 0.46
		_: return 0.34


func _leg_ik(target: Vector2) -> Array:
	# Resout une jambe a deux segments depuis une position de pied voulue.
	# Les angles obtenus utilisent le meme repere que `_leg_joints` et gardent
	# toujours le genou dans son sens anatomique.
	var min_reach := absf(LEG_UP - LEG_LO) + 0.01
	var max_reach := LEG_UP + LEG_LO - 0.01
	var reach := clampf(target.length(), min_reach, max_reach)
	if target.length_squared() > 0.0001:
		target *= reach / target.length()
	var cos_knee := clampf((reach * reach - LEG_UP * LEG_UP - LEG_LO * LEG_LO) /
		(2.0 * LEG_UP * LEG_LO), -1.0, 1.0)
	var knee_flex := -acos(cos_knee)
	var aim := atan2(target.x, target.y)
	var chain_offset := atan2(LEG_LO * sin(knee_flex), LEG_UP + LEG_LO * cos(knee_flex))
	return [aim - chain_offset, knee_flex]


func _pose_lerp(a: Dictionary, b: Dictionary, weight: float) -> Dictionary:
	var w := clampf(weight, 0.0, 1.0)
	var p := _copy_pose(a)
	p["lean"] = lerpf(float(a["lean"]), float(b["lean"]), w)
	p["drop"] = lerpf(float(a["drop"]), float(b["drop"]), w)
	for key in ["arm_b", "arm_f", "leg_b", "leg_f"]:
		p[key][0] = lerpf(float(a[key][0]), float(b[key][0]), w)
		p[key][1] = lerpf(float(a[key][1]), float(b[key][1]), w)
	return p


func _copy_pose(p: Dictionary) -> Dictionary:
	return {
		"lean": p["lean"],
		"drop": p["drop"],
		"arm_b": [p["arm_b"][0], p["arm_b"][1]],
		"arm_f": [p["arm_f"][0], p["arm_f"][1]],
		"leg_b": [p["leg_b"][0], p["leg_b"][1]],
		"leg_f": [p["leg_f"][0], p["leg_f"][1]],
	}


# Squelette complet en coordonnees locales (pixels), pour le rendu 3D.
# Chaque membre : [articulation intermediaire, extremite].
func skeleton() -> Dictionary:
	var hip := _hip()
	var sh := _shoulder()
	return {
		"hip": hip,
		"sh": sh,
		"head": _head_pos(),
		"arm_b": _joints(sh, _pose["arm_b"], ARM_UP, ARM_LO),
		"arm_f": _joints(sh, _pose["arm_f"], ARM_UP, ARM_LO),
		"leg_b": _leg_joints(hip, _pose["leg_b"]),
		"leg_f": _leg_joints(hip, _pose["leg_f"]),
		"lean": _pose["lean"] * facing,
		"hip_twist": _body_twist.x,
		"chest_twist": _body_twist.y,
		"turn_y": _turn_y,
		"hook_arc": _hook_arc,
		"motion": _motion,
		"external_clip": _external_clip_info,
		"external_guard": AttackLibrary.guard_clip_info(),
		"external_neutral": AttackLibrary.neutral_clip_info(),
		"external_crouch": AttackLibrary.crouch_clip_info(),
		"attack_progress": _attack_total_progress() if state == State.ATTACK else 0.0,
		"root_roll": float(_motion.get("roll", 0.0)),
		"spin": _spin,
		"facing": facing,
		"flash": _flash,
	}


func head_image() -> Image:
	# vignette carree deja recadree sur le visage, ou null
	if not has_photo():
		return null
	var r := Rect2i(_crop).intersection(Rect2i(Vector2i.ZERO, _head_img.get_size()))
	if r.size.x < 4 or r.size.y < 4:
		return null
	return _head_img.get_region(r)


func _hip() -> Vector2:
	return Vector2(0, HIP_Y + _pose["drop"])


func _shoulder() -> Vector2:
	var lean: float = _pose["lean"] * facing
	return _hip() + Vector2(sin(-lean), -cos(lean)) * TORSO_LEN


func _head_pos() -> Vector2:
	var lean: float = _pose["lean"] * facing
	return _shoulder() + Vector2(sin(-lean), -cos(lean)) * (head_radius() + 2.0)


# ------------------------------------------------------------
#  Rendu
# ------------------------------------------------------------
func _draw() -> void:
	if not draw_2d:
		return          # le corps est rendu par le rig 3D
	var hip := _hip()
	var sh := _shoulder()

	var back := col_dark
	var front := col_main
	var skin := COL_SKIN
	var glove := col_main.lightened(0.42)
	var boot := col_dark.darkened(0.30)
	if _flash > 0.01:
		back = back.lerp(Color.WHITE, _flash)
		front = front.lerp(Color.WHITE, _flash)
		skin = skin.lerp(Color.WHITE, _flash)
		glove = glove.lerp(Color.WHITE, _flash)
		boot = boot.lerp(Color.WHITE, _flash)

	# ombre au sol (jamais tournee, se resserre quand on saute)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var lift: float = clampf(1.0 - absf(global_position.y - spawn_pos.y) / 260.0, 0.35, 1.0)
	draw_circle(Vector2(0, 2), 21.0 * lift, Color(0, 0, 0, 0.30 * lift))

	# le reste du corps tourne autour du bassin pendant une projection / gros coup
	draw_set_transform(hip - hip.rotated(_spin), _spin, Vector2.ONE)

	_draw_swoosh()

	# ---- membres arriere (teinte sombre = profondeur) ----
	_draw_leg(hip, _pose["leg_b"], back, boot.darkened(0.15), 0.90)
	_draw_arm(sh, _pose["arm_b"], back, glove.darkened(0.28), 0.90)

	# ---- torse ----
	_draw_torso(hip, sh, front)

	# ---- membres avant ----
	_draw_leg(hip, _pose["leg_f"], front.lightened(0.06), boot, 1.0)
	_draw_arm(sh, _pose["arm_f"], front.lightened(0.10), glove, 1.0)

	# ---- cou + tete ----
	var hpos := _head_pos()
	var neck_dir := (hpos - sh).normalized()
	_taper(sh, sh + neck_dir * 7.0, 9.5, 7.5, skin.darkened(0.24))
	if not has_photo():
		_draw_head(hpos, skin, front)
	else:
		# disque de fond + liseré : la photo (sprite masque en cercle) se pose dessus
		var r := head_radius()
		draw_circle(hpos, r + 3.0, Color(0, 0, 0, 0.35))
		draw_circle(hpos, r + 1.5, front.lightened(0.20))

	# ---- garde ----
	if state == State.BLOCK:
		var a := 0.22 + 0.45 * block_energy
		draw_arc(sh + Vector2(facing * 6.0, 6.0), 34.0, -1.15 + (0.0 if facing > 0 else PI),
			1.15 + (0.0 if facing > 0 else PI), 20, Color(0.55, 0.85, 1.0, a), 5.0, true)


# ---- briques de dessin ----
func _is_kick() -> bool:
	return move_name in KICK_MOVES


func _strike_point() -> Vector2:
	# extremite du membre qui frappe (poing ou pied)
	if _is_kick():
		return _leg_joints(_hip(), _pose["leg_f"])[1]
	return _joints(_shoulder(), _pose["arm_f"], ARM_UP, ARM_LO)[1]


func _hitbox_world_point() -> Vector2:
	return global_position + hitbox_shape.position


func _swing_origin_key() -> Array:
	# [origine de l'articulation, cle de pose] du membre qui frappe
	if _is_kick():
		return [_hip(), "leg_f"]
	return [_shoulder(), "arm_f"]


func _draw_swoosh() -> void:
	# Arc de mouvement entre la position d'arme et la position actuelle.
	# (echantillonner les positions passees ne marche pas : la pose converge
	#  en quelques frames et tous les points se tassent au meme endroit.)
	if state != State.ATTACK or _phase > 1 or _move.is_empty():
		return
	var ok := _swing_origin_key()
	var origin: Vector2 = ok[0]
	var a_now: float = _pose[ok[1]][0] * facing
	if not _is_kick():
		a_now += _pose["lean"] * facing
	if absf(a_now - _swing_a0) < 0.15:
		return
	var r := origin.distance_to(_strike_point())
	var c := col_main.lightened(0.60)
	var steps := 10
	for i in steps:
		var t0 := float(i) / float(steps)
		var t1 := float(i + 1) / float(steps)
		var aa := lerpf(_swing_a0, a_now, t0)
		var ab := lerpf(_swing_a0, a_now, t1)
		_taper(origin + Vector2(sin(aa), cos(aa)) * r,
			origin + Vector2(sin(ab), cos(ab)) * r,
			1.5 + 15.0 * t0, 1.5 + 15.0 * t1,
			Color(c.r, c.g, c.b, 0.42 * t0))


func _taper(a: Vector2, b: Vector2, wa: float, wb: float, c: Color) -> void:
	# segment fusele : plus epais au depart qu'a l'arrivee
	var d := b - a
	if d.length_squared() < 0.0001:
		return
	var n := d.orthogonal().normalized()
	draw_colored_polygon(PackedVector2Array([
		a + n * wa * 0.5, b + n * wb * 0.5, b - n * wb * 0.5, a - n * wa * 0.5]), c)


func _joints(origin: Vector2, angles: Array, l1: float, l2: float) -> Array:
	var a1: float = angles[0] * facing + _pose["lean"] * facing
	var mid := origin + Vector2(sin(a1), cos(a1)) * l1
	var a2: float = a1 + angles[1] * facing
	return [mid, mid + Vector2(sin(a2), cos(a2)) * l2]


func _leg_joints(origin: Vector2, angles: Array) -> Array:
	# Le genou humain est une charniere : il flechit vers l'arriere dans le
	# repere du combattant. Les jambes partent du bassin et n'heritent pas de
	# l'inclinaison de la cage thoracique : le pied d'appui reste ainsi au sol.
	var a1: float = angles[0] * facing
	var knee := origin + Vector2(sin(a1), cos(a1)) * LEG_UP
	var flexion := clampf(angles[1], -KNEE_MAX_FLEX, KNEE_HYPEREXT)
	var a2: float = a1 + flexion * facing
	return [knee, knee + Vector2(sin(a2), cos(a2)) * LEG_LO]


func _draw_arm(sh: Vector2, angles: Array, c: Color, glove: Color, k: float) -> void:
	var j := _joints(sh, angles, ARM_UP, ARM_LO)
	draw_circle(sh, 8.2 * k, c)                       # epaule
	_taper(sh, j[0], 13.0 * k, 9.6 * k, c)            # bras
	draw_circle(j[0], 4.8 * k, c)                     # coude
	_taper(j[0], j[1], 9.6 * k, 7.6 * k, c)           # avant-bras
	draw_circle(j[1], 6.6 * k, glove)                 # gant
	draw_circle(j[1] + (j[1] - j[0]).normalized() * 1.6, 4.6 * k, glove.lightened(0.16))


func _draw_leg(hip: Vector2, angles: Array, c: Color, boot: Color, k: float) -> void:
	var j := _leg_joints(hip, angles)
	_taper(hip, j[0], 16.5 * k, 11.0 * k, c)          # cuisse
	draw_circle(j[0], 5.5 * k, c)                     # genou
	_taper(j[0], j[1], 11.0 * k, 8.0 * k, c)          # mollet
	# pied oriente vers l'avant
	var foot_dir := Vector2(facing, 0.0)
	_taper(j[1] - foot_dir * 2.0, j[1] + foot_dir * 9.0, 8.4 * k, 6.0 * k, boot)
	draw_circle(j[1], 4.4 * k, boot)


func _draw_torso(hip: Vector2, sh: Vector2, c: Color) -> void:
	var up := (sh - hip)
	var n := up.orthogonal().normalized()
	var mid := hip + up * 0.46
	# buste : epaules larges -> taille -> bassin
	draw_colored_polygon(PackedVector2Array([
		sh + n * SH_W * 0.5, sh - n * SH_W * 0.5,
		mid - n * WAIST_W * 0.5, hip - n * HIP_W * 0.5,
		hip + n * HIP_W * 0.5, mid + n * WAIST_W * 0.5]), c)
	# ombre sur le flanc arriere pour donner du volume
	draw_colored_polygon(PackedVector2Array([
		sh - n * SH_W * 0.5, sh - n * SH_W * 0.16,
		mid - n * WAIST_W * 0.16, hip - n * HIP_W * 0.14,
		hip - n * HIP_W * 0.5, mid - n * WAIST_W * 0.5]), c.darkened(0.16))
	# ceinture
	_taper(hip + n * HIP_W * 0.5, hip - n * HIP_W * 0.5, 6.0, 6.0, c.darkened(0.34))


func _draw_head(p: Vector2, skin: Color, c: Color) -> void:
	var fwd := Vector2(facing, 0.0).rotated(_pose["lean"] * facing)
	var up := Vector2(0, -1).rotated(_pose["lean"] * facing)
	var hair := c.darkened(0.34)
	draw_circle(p - fwd * 3.0 + up * 2.5, HEAD_R * 1.02, hair)   # masse arriere
	draw_circle(p, HEAD_R * 0.97, skin)                          # visage
	draw_circle(p + fwd * 3.8 - up * 5.2, HEAD_R * 0.70, skin)   # machoire
	draw_circle(p - fwd * 1.0 + up * 7.6, HEAD_R * 0.70, hair)   # frange
	draw_circle(p + fwd * 6.2 + up * 1.4, 2.6, Color(0.08, 0.09, 0.13))
	_taper(p + fwd * 3.0 + up * 5.8, p + fwd * 8.8 + up * 4.2, 2.6, 1.9, hair)


# ------------------------------------------------------------
#  Visage importe depuis une photo
# ------------------------------------------------------------
func has_photo() -> bool:
	return _head_img != null


func head_radius() -> float:
	# un vrai visage a besoin de plus de pixels qu'une tete dessinee
	return PHOTO_HEAD_R if has_photo() else HEAD_R


func set_head_photo(img: Image, who: String = "") -> void:
	_head_img = Photo.prepare(img)
	_crop = Photo.find_face(_head_img)
	if who != "":
		display_name = who.to_upper()
	# la tenue reprend la couleur des vetements, mais on garde une bonne part
	# du bleu/rouge d'origine : sinon deux personnes en noir seraient identiques
	var outfit := Photo.outfit_color(_head_img, _crop)
	col_main = base_main.lerp(outfit, 0.40)
	col_dark = base_dark.lerp(outfit.darkened(0.35), 0.40)
	_apply_crop()


func clear_photo() -> void:
	_head_img = null
	head_sprite.texture = null
	head_sprite.visible = false
	col_main = base_main
	col_dark = base_dark
	display_name = ""


func zoom_head(factor: float) -> void:
	if not has_photo():
		return
	var c := _crop.get_center()
	var side: float = _crop.size.x * factor
	_crop = Photo.clamp_square(
		Rect2(c.x - side * 0.5, c.y - side * 0.5, side, side), _head_img.get_size())
	_apply_crop()


func pan_head(screen_delta: Vector2) -> void:
	if not has_photo():
		return
	# on convertit le deplacement ecran en pixels de la photo
	var k: float = _crop.size.x / (head_radius() * 2.0)
	_crop = Photo.clamp_square(
		Rect2(_crop.position - screen_delta * k, _crop.size), _head_img.get_size())
	_apply_crop()


func recenter_head() -> void:
	if not has_photo():
		return
	_crop = Photo.find_face(_head_img)
	_apply_crop()


func _apply_crop() -> void:
	# On decoupe vraiment l'image au lieu d'utiliser region_enabled : avec une
	# region, les UV du shader couvrent la zone dans l'atlas et non le quad,
	# donc le masque circulaire porterait sur les mauvaises coordonnees.
	var r := Rect2i(_crop).intersection(Rect2i(Vector2i.ZERO, _head_img.get_size()))
	if r.size.x < 4 or r.size.y < 4:
		return
	var sub := _head_img.get_region(r)
	head_sprite.texture = ImageTexture.create_from_image(sub)
	var d := head_radius() * 2.0
	head_sprite.scale = Vector2(d / float(sub.get_width()), d / float(sub.get_height()))
	head_sprite.visible = draw_2d      # en 3D c'est le rig qui porte le visage


func head_state() -> Dictionary:
	return {"crop": [_crop.position.x, _crop.position.y, _crop.size.x], "name": display_name}


func restore_head_state(d: Dictionary) -> void:
	if not has_photo() or not d.has("crop"):
		return
	var c: Array = d["crop"]
	if c.size() >= 3:
		_crop = Photo.clamp_square(
			Rect2(float(c[0]), float(c[1]), float(c[2]), float(c[2])), _head_img.get_size())
		_apply_crop()
	if d.has("name"):
		display_name = str(d["name"])


func _circle_mask() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	float d = length(UV - vec2(0.5));
	if (d > 0.5) { discard; }
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= smoothstep(0.500, 0.465, d);   // bord adouci
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m
