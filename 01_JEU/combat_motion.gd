extends RefCounted
class_name CombatMotion

# Mouvement de reference pour le bas du corps.
# Les directions sont une reduction (8 poses) des clips CC0 Walk_Loop et
# Jog_Fwd_Loop de la Universal Animation Library de Quaternius. Le melange
# garde l'energie d'une course de jeu de combat sans la montee de genou
# caricaturale de l'ancien cycle procedural.
const GAIT := [
	{"bob": 0.99, "leg_f": [Vector3(-0.4784, -0.8781, -0.0077), Vector3(-0.8635, -0.5041, 0.0144)],
		"leg_b": [Vector3(0.4990, -0.8666, -0.0056), Vector3(0.3701, -0.9290, -0.0003)]},
	{"bob": 3.36, "leg_f": [Vector3(0.1516, -0.9884, 0.0041), Vector3(-0.8971, -0.4415, 0.0147)],
		"leg_b": [Vector3(0.4698, -0.8828, 0.0025), Vector3(-0.4730, -0.8809, 0.0171)]},
	{"bob": -1.79, "leg_f": [Vector3(0.7639, -0.6452, 0.0150), Vector3(-0.5873, -0.8090, 0.0240)],
		"leg_b": [Vector3(-0.1626, -0.9865, 0.0198), Vector3(-0.5721, -0.8200, 0.0189)]},
	{"bob": -2.87, "leg_f": [Vector3(0.8128, -0.5823, 0.0182), Vector3(-0.1053, -0.9942, 0.0212)],
		"leg_b": [Vector3(-0.2680, -0.9631, 0.0233), Vector3(-0.7125, -0.7016, 0.0121)]},
	{"bob": 0.77, "leg_f": [Vector3(0.5283, -0.8490, 0.0102), Vector3(0.3300, -0.9440, 0.0084)],
		"leg_b": [Vector3(-0.3652, -0.9308, 0.0150), Vector3(-0.8766, -0.4812, -0.0075)]},
	{"bob": 3.46, "leg_f": [Vector3(0.4988, -0.8667, 0.0035), Vector3(-0.4582, -0.8888, -0.0107)],
		"leg_b": [Vector3(0.2643, -0.9645, 0.0022), Vector3(-0.8809, -0.4732, -0.0094)]},
	{"bob": -1.53, "leg_f": [Vector3(-0.1692, -0.9855, -0.0149), Vector3(-0.5828, -0.8125, -0.0146)],
		"leg_b": [Vector3(0.7641, -0.6451, -0.0105), Vector3(-0.6379, -0.7698, -0.0189)]},
	{"bob": -2.92, "leg_f": [Vector3(-0.3172, -0.9482, -0.0175), Vector3(-0.7047, -0.7095, -0.0065)],
		"leg_b": [Vector3(0.8204, -0.5716, -0.0154), Vector3(-0.1102, -0.9938, -0.0135)]},
]

# Clips corporels complets. Les trajectoires de jab, crochet, crochet au corps,
# front kick et mawashi sont des reductions de captures CMU (120 i/s), puis
# recalees sur les timings courts du jeu. Les valeurs de rotation ont ete
# exagerees avec mesure : appui/bassin d'abord, cage/membre ensuite.
# Repere : +X vers l'adversaire, +Y vers le haut, +Z vers la camera.
const ATTACKS := {
	"jab": [
		{"t": 0.00, "weight": 0.0, "roll": 0.0, "advance": 0.0, "turn": 0.0, "hip": 0.0, "chest": 0.0,
			"arm_f": [Vector3(-0.5397, -0.7461, 0.3898), Vector3(0.9352, -0.2940, -0.1974)],
			"arm_b": [Vector3(0.3994, -0.4164, -0.8168), Vector3(0.8365, 0.5162, 0.1839)],
			"leg_f": [Vector3(-0.0316, -0.9542, 0.2975), Vector3(-0.6705, -0.5255, 0.5236)],
			"leg_b": [Vector3(0.5432, -0.7611, -0.3546), Vector3(-0.3339, -0.8541, -0.3988)]},
		{"t": 0.20, "weight": 0.76, "roll": -0.05, "advance": -2.0, "turn": -0.08, "hip": -0.06, "chest": -0.14,
			"arm_f": [Vector3(0.6520, -0.0976, 0.7519), Vector3(0.4594, 0.1194, -0.8801)],
			"arm_b": [Vector3(0.5126, -0.8421, -0.1675), Vector3(0.6293, 0.6402, 0.4407)],
			"leg_f": [Vector3(-0.2564, -0.9537, -0.1572), Vector3(-0.8983, -0.4329, -0.0747)],
			"leg_b": [Vector3(0.7256, -0.6848, -0.0674), Vector3(-0.0517, -0.9055, -0.4212)]},
		{"t": 0.30, "weight": 0.96, "roll": -0.10, "advance": 3.0, "turn": 0.06, "hip": 0.08, "chest": 0.20,
			"arm_f": [Vector3(0.9832, 0.1136, 0.1427), Vector3(0.8357, 0.0838, -0.5427)],
			"arm_b": [Vector3(0.2474, -0.9640, -0.0973), Vector3(0.8144, 0.5376, 0.2186)],
			"leg_f": [Vector3(-0.2449, -0.9494, -0.1966), Vector3(-0.8843, -0.4324, -0.1762)],
			"leg_b": [Vector3(0.7477, -0.6605, -0.0689), Vector3(-0.0442, -0.9283, -0.3692)]},
		{"t": 0.38, "weight": 1.0, "roll": -0.14, "advance": 6.0, "turn": 0.14, "hip": 0.14, "chest": 0.34,
			"arm_f": [Vector3(0.9968, 0.0319, -0.0728), Vector3(0.9458, 0.2697, -0.1809)],
			"arm_b": [Vector3(0.1451, -0.9892, -0.0204), Vector3(0.8505, 0.4965, 0.1734)],
			"leg_f": [Vector3(-0.3025, -0.9285, -0.2154), Vector3(-0.8521, -0.4685, -0.2335)],
			"leg_b": [Vector3(0.7495, -0.6615, -0.0272), Vector3(-0.0344, -0.9513, -0.3065)]},
		{"t": 0.68, "weight": 0.56, "roll": -0.08, "advance": 3.0, "turn": 0.06, "hip": 0.06, "chest": 0.16,
			"arm_f": [Vector3(0.8577, -0.4793, 0.1860), Vector3(0.7756, 0.0669, -0.6276)],
			"arm_b": [Vector3(-0.0533, -0.9979, -0.0362), Vector3(0.8274, 0.5490, 0.1184)],
			"leg_f": [Vector3(-0.3218, -0.9401, -0.1124), Vector3(-0.8306, -0.5568, 0.0075)],
			"leg_b": [Vector3(0.7288, -0.6793, -0.0862), Vector3(-0.1193, -0.9414, -0.3156)]},
		{"t": 1.00, "weight": 0.0, "roll": 0.0, "advance": 0.0, "turn": 0.0, "hip": 0.0, "chest": 0.0,
			"arm_f": [Vector3(0.3156, -0.8776, 0.3608), Vector3(0.8072, -0.0037, -0.5903)],
			"arm_b": [Vector3(-0.0035, -0.9874, -0.1582), Vector3(0.6950, 0.6704, 0.2599)],
			"leg_f": [Vector3(-0.1438, -0.9884, -0.0482), Vector3(-0.7066, -0.6969, 0.1229)],
			"leg_b": [Vector3(0.6063, -0.7478, -0.2704), Vector3(-0.0979, -0.9326, -0.3473)]},
	],
	"hook": [
		{"t": 0.00, "weight": 0.0, "roll": 0.0, "advance": 0.0, "turn": 0.0, "hip": 0.0, "chest": 0.0,
			"arm_f": [Vector3(-0.6077, -0.7759, 0.1693), Vector3(0.7022, -0.6555, 0.2780)],
			"arm_b": [Vector3(0.1028, -0.6550, -0.7486), Vector3(0.7361, 0.5795, -0.3498)],
			"leg_f": [Vector3(0.2759, -0.8970, 0.3453), Vector3(-0.6056, -0.6838, 0.4070)],
			"leg_b": [Vector3(0.5100, -0.7876, -0.3458), Vector3(-0.0523, -0.9034, -0.4255)]},
		{"t": 0.20, "weight": 0.78, "roll": -0.04, "advance": -2.0, "turn": -0.16, "hip": -0.12, "chest": -0.26,
			"arm_f": [Vector3(-0.2666, -0.9275, 0.2621), Vector3(0.7474, 0.1788, 0.6398)],
			"arm_b": [Vector3(0.5160, -0.8333, -0.1983), Vector3(0.5066, 0.7972, 0.3284)],
			"leg_f": [Vector3(-0.1251, -0.9855, 0.1146), Vector3(-0.9303, -0.3048, -0.2042)],
			"leg_b": [Vector3(0.6979, -0.7010, 0.1470), Vector3(0.1021, -0.9860, -0.1317)]},
		{"t": 0.29, "weight": 0.97, "roll": -0.08, "advance": 2.0, "turn": 0.10, "hip": 0.18, "chest": 0.34,
			"arm_f": [Vector3(0.4561, -0.6391, 0.6194), Vector3(0.6023, 0.7557, 0.2571)],
			"arm_b": [Vector3(0.4754, -0.8599, -0.1859), Vector3(0.5325, 0.8090, 0.2490)],
			"leg_f": [Vector3(-0.0854, -0.9962, 0.0187), Vector3(-0.8905, -0.2825, -0.3567)],
			"leg_b": [Vector3(0.6571, -0.7014, 0.2760), Vector3(0.1783, -0.9821, 0.0611)]},
		{"t": 0.36, "weight": 1.0, "roll": -0.13, "advance": 6.0, "turn": 0.28, "hip": 0.32, "chest": 0.62,
			"arm_f": [Vector3(0.9172, -0.3133, 0.2463), Vector3(0.4960, 0.8530, -0.1625)],
			"arm_b": [Vector3(0.4154, -0.8777, -0.2389), Vector3(0.5586, 0.8225, 0.1072)],
			"leg_f": [Vector3(-0.0901, -0.9958, -0.0140), Vector3(-0.8856, -0.3808, -0.2659)],
			"leg_b": [Vector3(0.6509, -0.7091, 0.2712), Vector3(0.1678, -0.9807, 0.1005)]},
		{"t": 0.67, "weight": 0.58, "roll": -0.07, "advance": 3.0, "turn": 0.10, "hip": 0.12, "chest": 0.24,
			"arm_f": [Vector3(0.8194, -0.2813, -0.4995), Vector3(-0.0591, 0.2286, -0.9717)],
			"arm_b": [Vector3(0.2655, -0.8778, -0.3987), Vector3(0.5692, 0.7798, 0.2606)],
			"leg_f": [Vector3(-0.2806, -0.9549, -0.0976), Vector3(-0.8335, -0.4824, -0.2692)],
			"leg_b": [Vector3(0.6432, -0.7007, 0.3087), Vector3(0.0910, -0.9886, 0.1200)]},
		{"t": 1.00, "weight": 0.0, "roll": 0.0, "advance": 0.0, "turn": 0.0, "hip": 0.0, "chest": 0.0,
			"arm_f": [Vector3(0.3296, -0.8690, -0.3691), Vector3(0.0595, 0.3647, -0.9292)],
			"arm_b": [Vector3(-0.0669, -0.9228, -0.3795), Vector3(0.6769, 0.7361, -0.0029)],
			"leg_f": [Vector3(-0.1973, -0.9787, 0.0577), Vector3(-0.8958, -0.4012, -0.1916)],
			"leg_b": [Vector3(0.6674, -0.7037, 0.2437), Vector3(0.0317, -0.9993, 0.0203)]},
	],
	"body_hook": [
		{"t": 0.00, "weight": 0.0, "roll": 0.0, "advance": 0.0, "turn": 0.0, "hip": 0.0, "chest": 0.0,
			"arm_f": [Vector3(0.7739, 0.0716, 0.6293), Vector3(0.9518, 0.2778, -0.1299)]},
		{"t": 0.21, "weight": 0.80, "roll": -0.14, "advance": -2.0, "turn": -0.14, "hip": -0.12, "chest": -0.28,
			"arm_f": [Vector3(0.7900, -0.2523, 0.5588), Vector3(0.9088, 0.3190, -0.2689)]},
		{"t": 0.30, "weight": 0.97, "roll": -0.20, "advance": 1.0, "turn": 0.08, "hip": 0.16, "chest": 0.30,
			"arm_f": [Vector3(0.7181, -0.4598, 0.5223), Vector3(0.8455, 0.3394, -0.4122)]},
		{"t": 0.37, "weight": 1.0, "roll": -0.24, "advance": 5.0, "turn": 0.25, "hip": 0.30, "chest": 0.56,
			"arm_f": [Vector3(0.6197, -0.6144, 0.4884), Vector3(0.8117, 0.3298, -0.4821)]},
		{"t": 0.68, "weight": 0.56, "roll": -0.12, "advance": 2.0, "turn": 0.08, "hip": 0.10, "chest": 0.20,
			"arm_f": [Vector3(0.1356, -0.8772, 0.4605), Vector3(0.8680, 0.0786, -0.4904)]},
		{"t": 1.00, "weight": 0.0, "roll": 0.0, "advance": 0.0, "turn": 0.0, "hip": 0.0, "chest": 0.0,
			"arm_f": [Vector3(-0.0082, -0.8973, 0.4413), Vector3(0.9293, 0.0880, -0.3587)]},
	],
	"uppercut": [
		{"t": 0.00, "weight": 0.0, "roll": 0.0, "advance": 0.0, "turn": 0.0, "hip": 0.0, "chest": 0.0,
			"arm_f": [Vector3(-0.8583, -0.4335, -0.2747), Vector3(-0.4275, -0.8428, 0.3271)]},
		{"t": 0.24, "weight": 0.78, "roll": -0.18, "advance": -2.0, "turn": -0.12, "hip": -0.14, "chest": -0.24,
			"arm_f": [Vector3(-0.4643, -0.8802, -0.0986), Vector3(-0.0377, -0.8044, 0.5929)]},
		{"t": 0.34, "weight": 0.96, "roll": -0.08, "advance": 2.0, "turn": 0.06, "hip": 0.12, "chest": 0.22,
			"arm_f": [Vector3(-0.0967, -0.8671, 0.4887), Vector3(0.1975, -0.2175, 0.9559)]},
		{"t": 0.41, "weight": 1.0, "roll": 0.06, "advance": 5.0, "turn": 0.20, "hip": 0.24, "chest": 0.44,
			"arm_f": [Vector3(0.6200, 0.3000, 0.7242), Vector3(0.5200, 0.8200, -0.2387)]},
		{"t": 0.70, "weight": 0.52, "roll": 0.02, "advance": 2.0, "turn": 0.06, "hip": 0.08, "chest": 0.16,
			"arm_f": [Vector3(0.8418, 0.3651, -0.3975), Vector3(0.2354, 0.6967, -0.6777)]},
		{"t": 1.00, "weight": 0.0, "roll": 0.0, "advance": 0.0, "turn": 0.0, "hip": 0.0, "chest": 0.0,
			"arm_f": [Vector3(0.4700, -0.3994, -0.7872), Vector3(-0.1720, 0.0670, -0.9828)]},
	],
	"front_kick": [
		{"t": 0.00, "weight": 0.0, "roll": 0.0,
			"arm_f": [Vector3(-0.2788, -0.8688, 0.4091), Vector3(0.9076, -0.3918, -0.1506)],
			"arm_b": [Vector3(0.0457, -0.9499, -0.3093), Vector3(0.9947, -0.0614, 0.0823)],
			"leg_f": [Vector3(0.7434, -0.6599, 0.1089), Vector3(-0.8177, -0.5650, -0.1103)]},
		{"t": 0.17, "weight": 0.82, "roll": -0.08,
			"arm_f": [Vector3(-0.4395, -0.8744, 0.2053), Vector3(0.7599, -0.6387, 0.1209)],
			"arm_b": [Vector3(0.3213, -0.8888, -0.3267), Vector3(0.8970, 0.0477, 0.4395)],
			"leg_f": [Vector3(0.7004, 0.6792, 0.2194), Vector3(0.3056, -0.9398, 0.1529)]},
		{"t": 0.26, "weight": 0.98, "roll": -0.16,
			"arm_f": [Vector3(-0.3973, -0.8784, 0.2655), Vector3(0.7209, -0.6853, 0.1033)],
			"arm_b": [Vector3(0.3446, -0.8806, -0.3254), Vector3(0.8984, 0.1052, 0.4264)],
			"leg_f": [Vector3(0.7213, 0.6752, 0.1545), Vector3(0.8893, -0.1554, 0.4301)]},
		{"t": 0.32, "weight": 1.0, "roll": -0.20,
			"arm_f": [Vector3(-0.3583, -0.8758, 0.3233), Vector3(0.7127, -0.6944, 0.0993)],
			"arm_b": [Vector3(0.3200, -0.8875, -0.3315), Vector3(0.9171, 0.1340, 0.3756)],
			"leg_f": [Vector3(0.7738, 0.6097, 0.1719), Vector3(0.8835, 0.3051, 0.3555)]},
		{"t": 0.65, "weight": 0.58, "roll": -0.08,
			"arm_f": [Vector3(-0.3151, -0.9021, 0.2948), Vector3(0.6763, -0.6879, 0.2636)],
			"arm_b": [Vector3(0.1518, -0.9166, -0.3698), Vector3(0.9459, 0.0586, 0.3191)],
			"leg_f": [Vector3(0.3837, 0.8500, 0.3609), Vector3(0.3384, -0.9093, -0.2420)]},
		{"t": 1.00, "weight": 0.0, "roll": 0.0,
			"arm_f": [Vector3(-0.3932, -0.8483, 0.3546), Vector3(0.6368, -0.6928, 0.3384)],
			"arm_b": [Vector3(0.0444, -0.9547, -0.2943), Vector3(0.9548, -0.0513, 0.2928)],
			"leg_f": [Vector3(0.8184, 0.2979, 0.4914), Vector3(-0.2001, -0.9325, -0.3007)]},
	],
	"middle_kick": [
		{"t": 0.00, "weight": 0.0, "roll": 0.0,
			"arm_f": [Vector3(0.0349, -0.8207, 0.5703), Vector3(0.9525, 0.1393, -0.2707)],
			"arm_b": [Vector3(-0.1079, -0.8879, -0.4473), Vector3(0.9456, -0.0426, -0.3226)],
			"leg_f": [Vector3(0.6877, -0.5832, 0.4324), Vector3(-0.8547, -0.4392, -0.2769)]},
		{"t": 0.18, "weight": 0.82, "roll": -0.12,
			"arm_f": [Vector3(-0.6921, -0.7198, -0.0539), Vector3(0.7400, -0.3707, 0.5612)],
			"arm_b": [Vector3(0.6048, -0.6782, -0.4175), Vector3(0.8273, 0.2921, 0.4798)],
			"leg_f": [Vector3(0.6979, 0.4082, 0.5885), Vector3(-0.4448, -0.7823, 0.4362)]},
		{"t": 0.28, "weight": 0.98, "roll": -0.20,
			"arm_f": [Vector3(-0.7592, -0.6416, -0.1091), Vector3(0.6015, -0.5925, 0.5358)],
			"arm_b": [Vector3(0.7115, -0.6235, -0.3241), Vector3(0.7870, 0.3136, 0.5313)],
			"leg_f": [Vector3(0.6913, 0.3257, 0.6450), Vector3(0.3919, 0.2684, 0.8800)]},
		{"t": 0.32, "weight": 1.0, "roll": -0.26,
			"arm_f": [Vector3(-0.7803, -0.6183, -0.0938), Vector3(0.4946, -0.6548, 0.5715)],
			"arm_b": [Vector3(0.7497, -0.5999, -0.2794), Vector3(0.7555, 0.3469, 0.5557)],
			"leg_f": [Vector3(0.7800, 0.1000, 0.6177), Vector3(0.9650, 0.0500, -0.2573)]},
		{"t": 0.68, "weight": 0.56, "roll": -0.10,
			"arm_f": [Vector3(-0.8410, -0.5222, -0.1415), Vector3(-0.2612, -0.3955, 0.8805)],
			"arm_b": [Vector3(0.6128, -0.7726, -0.1663), Vector3(0.5971, 0.3724, 0.7104)],
			"leg_f": [Vector3(0.3250, 0.6533, 0.6838), Vector3(-0.3080, -0.8747, -0.3742)]},
		{"t": 1.00, "weight": 0.0, "roll": 0.0,
			"arm_f": [Vector3(-0.8454, -0.5205, 0.1200), Vector3(0.1726, -0.1518, 0.9732)],
			"arm_b": [Vector3(0.1623, -0.9637, -0.2121), Vector3(0.6934, 0.1981, 0.6928)],
			"leg_f": [Vector3(0.3487, 0.4310, 0.8322), Vector3(-0.2455, -0.7361, -0.6308)]},
	],
	"high_kick": [
		{"t": 0.00, "weight": 0.0, "roll": 0.0,
			"arm_f": [Vector3(0.0349, -0.8207, 0.5703), Vector3(0.9525, 0.1393, -0.2707)],
			"arm_b": [Vector3(-0.1079, -0.8879, -0.4473), Vector3(0.9456, -0.0426, -0.3226)],
			"leg_f": [Vector3(0.6877, -0.5832, 0.4324), Vector3(-0.8547, -0.4392, -0.2769)]},
		{"t": 0.18, "weight": 0.82, "roll": -0.16,
			"arm_f": [Vector3(-0.6921, -0.7198, -0.0539), Vector3(0.7400, -0.3707, 0.5612)],
			"arm_b": [Vector3(0.6048, -0.6782, -0.4175), Vector3(0.8273, 0.2921, 0.4798)],
			"leg_f": [Vector3(0.6979, 0.4082, 0.5885), Vector3(-0.4448, -0.7823, 0.4362)]},
		{"t": 0.28, "weight": 0.98, "roll": -0.26,
			"arm_f": [Vector3(-0.7592, -0.6416, -0.1091), Vector3(0.6015, -0.5925, 0.5358)],
			"arm_b": [Vector3(0.7115, -0.6235, -0.3241), Vector3(0.7870, 0.3136, 0.5313)],
			"leg_f": [Vector3(0.6913, 0.3257, 0.6450), Vector3(0.3919, 0.2684, 0.8800)]},
		{"t": 0.37, "weight": 1.0, "roll": -0.34,
			"arm_f": [Vector3(-0.7803, -0.6183, -0.0938), Vector3(0.4946, -0.6548, 0.5715)],
			"arm_b": [Vector3(0.7497, -0.5999, -0.2794), Vector3(0.7555, 0.3469, 0.5557)],
			"leg_f": [Vector3(0.6200, 0.5800, 0.5280), Vector3(0.8800, 0.4300, -0.2000)]},
		{"t": 0.68, "weight": 0.56, "roll": -0.13,
			"arm_f": [Vector3(-0.8410, -0.5222, -0.1415), Vector3(-0.2612, -0.3955, 0.8805)],
			"arm_b": [Vector3(0.6128, -0.7726, -0.1663), Vector3(0.5971, 0.3724, 0.7104)],
			"leg_f": [Vector3(0.3250, 0.6533, 0.6838), Vector3(-0.3080, -0.8747, -0.3742)]},
		{"t": 1.00, "weight": 0.0, "roll": 0.0,
			"arm_f": [Vector3(-0.8454, -0.5205, 0.1200), Vector3(0.1726, -0.1518, 0.9732)],
			"arm_b": [Vector3(0.1623, -0.9637, -0.2121), Vector3(0.6934, 0.1981, 0.6928)],
			"leg_f": [Vector3(0.3487, 0.4310, 0.8322), Vector3(-0.2455, -0.7361, -0.6308)]},
	],
	"spinning_kick": [
		{"t": 0.00, "weight": 0.0, "roll": 0.0,
			"leg_f": [Vector3(0.06, -0.99, 0.08), Vector3(-0.10, -0.98, -0.16)],
			"arm_f": [Vector3(0.12, -0.95, 0.28), Vector3(0.08, 0.94, -0.33)],
			"arm_b": [Vector3(0.10, -0.96, -0.27), Vector3(0.06, 0.94, 0.34)]},
		{"t": 0.13, "weight": 0.42, "roll": 0.02,
			"leg_f": [Vector3(-0.28, -0.76, 0.58), Vector3(0.38, -0.76, -0.52)],
			"arm_f": [Vector3(0.06, -0.95, 0.30), Vector3(0.10, 0.94, -0.33)],
			"arm_b": [Vector3(0.04, -0.96, -0.28), Vector3(0.08, 0.94, 0.34)]},
		{"t": 0.25, "weight": 0.82, "roll": 0.14,
			"leg_f": [Vector3(-0.68, -0.34, 0.65), Vector3(0.42, -0.48, -0.77)],
			"arm_f": [Vector3(-0.08, -0.95, 0.29), Vector3(0.12, 0.94, -0.32)],
			"arm_b": [Vector3(-0.06, -0.96, -0.27), Vector3(0.10, 0.94, 0.33)]},
		{"t": 0.37, "weight": 1.0, "roll": 0.34,
			"leg_f": [Vector3(-0.94, 0.18, 0.29), Vector3(-0.98, -0.04, -0.19)],
			"arm_f": [Vector3(-0.14, -0.95, 0.27), Vector3(0.12, 0.94, -0.31)],
			"arm_b": [Vector3(-0.12, -0.96, -0.25), Vector3(0.10, 0.94, 0.32)]},
		{"t": 0.49, "weight": 1.0, "roll": 0.34,
			"leg_f": [Vector3(-0.94, 0.18, 0.29), Vector3(-0.98, -0.04, -0.19)],
			"arm_f": [Vector3(-0.14, -0.95, 0.27), Vector3(0.12, 0.94, -0.31)],
			"arm_b": [Vector3(-0.12, -0.96, -0.25), Vector3(0.10, 0.94, 0.32)]},
		{"t": 0.61, "weight": 0.90, "roll": 0.26,
			"leg_f": [Vector3(-0.64, -0.34, 0.69), Vector3(0.38, -0.55, -0.74)],
			"arm_f": [Vector3(-0.04, -0.95, 0.30), Vector3(0.10, 0.94, -0.33)],
			"arm_b": [Vector3(-0.02, -0.96, -0.28), Vector3(0.08, 0.94, 0.34)]},
		{"t": 0.79, "weight": 0.45, "roll": 0.10,
			"leg_f": [Vector3(-0.20, -0.88, 0.43), Vector3(0.22, -0.93, -0.30)],
			"arm_f": [Vector3(0.08, -0.95, 0.30), Vector3(0.08, 0.94, -0.34)],
			"arm_b": [Vector3(0.06, -0.96, -0.28), Vector3(0.06, 0.94, 0.34)]},
		{"t": 1.00, "weight": 0.0, "roll": 0.0,
			"leg_f": [Vector3(0.06, -0.99, 0.08), Vector3(-0.10, -0.98, -0.16)],
			"arm_f": [Vector3(0.12, -0.95, 0.28), Vector3(0.08, 0.94, -0.33)],
			"arm_b": [Vector3(0.10, -0.96, -0.27), Vector3(0.06, 0.94, 0.34)]},
	],
}


static func sample_gait(cycle: float, direction: float) -> Dictionary:
	# En recul, le combattant ne se retourne pas : il rejoue le pas en sens
	# inverse tout en conservant genoux, bassin et garde face a l'adversaire.
	# La chaine 3D de course avant n'est donc pas miroitee. L'IK au sol pilote
	# le shuffle arriere et garde chaque plante sous son appui.
	var gait_cycle := cycle if direction >= 0.0 else 1.0 - cycle
	var pos := fposmod(gait_cycle, 1.0) * float(GAIT.size())
	var i0 := int(floor(pos)) % GAIT.size()
	var i1 := (i0 + 1) % GAIT.size()
	var w := _smooth(pos - floor(pos))
	var out := {
		"leg_f": _chain_lerp(GAIT[i0]["leg_f"], GAIT[i1]["leg_f"], w),
		"leg_b": _chain_lerp(GAIT[i0]["leg_b"], GAIT[i1]["leg_b"], w),
		"drop": lerpf(float(GAIT[i0]["bob"]), float(GAIT[i1]["bob"]), w),
		# Les directions 2D sont calculees par IK avec un pied d'appui exact.
		# Le clip de reference ne fournit plus que le rythme vertical : ecraser
		# les jambes ici recreerait le flottement du modele importe.
		"weight": 0.0,
		"roll": 0.0,
	}
	return out


static func sample_attack(move_name: String, progress: float) -> Dictionary:
	if not ATTACKS.has(move_name):
		return {}
	var frames: Array = ATTACKS[move_name]
	var q := clampf(progress, 0.0, 1.0)
	var a: Dictionary = frames[0]
	var b: Dictionary = frames[frames.size() - 1]
	for i in range(frames.size() - 1):
		if q <= float(frames[i + 1]["t"]):
			a = frames[i]
			b = frames[i + 1]
			break
	var span := maxf(float(b["t"]) - float(a["t"]), 0.0001)
	var w := _smooth((q - float(a["t"])) / span)
	var out := {
		"weight": lerpf(float(a["weight"]), float(b["weight"]), w),
		"roll": lerpf(float(a["roll"]), float(b["roll"]), w),
	}
	for key in ["advance", "turn", "hip", "chest", "drop"]:
		if a.has(key) and b.has(key):
			out[key] = lerpf(float(a[key]), float(b[key]), w)
	for key in ["arm_f", "arm_b", "leg_f", "leg_b"]:
		# Le coup retourne conserve la chaine 2D deja calibree sur la cible ;
		# son clip 3D pilote la rotation, le buste et les bras. Remplacer aussi
		# la jambe apres un demi-tour la projetait dans l'axe de profondeur.
		if move_name == "spinning_kick" and key == "leg_f":
			continue
		# Les captures de boxe comprennent des pas libres adaptes a une grande
		# salle. Dans l'arene, jab et crochet gardent leur stance : le transfert
		# de poids est porte par le bassin, pas par un pied qui decolle.
		if move_name in ["jab", "hook"] and key in ["leg_f", "leg_b"]:
			continue
		if a.has(key) and b.has(key):
			out[key] = _chain_lerp(a[key], b[key], w)
	# Un crochet au corps doit pousser depuis le sol. L'ancienne pose 2D
	# rapprochait les deux genoux et produisait une silhouette croisee. Ces
	# deux chaines ouvrent l'appui : genou avant vers la cible, genou arriere
	# en contrepoids, tout en conservant les deux pieds sous le bassin.
	if move_name == "body_hook":
		out["leg_f"] = [
			Vector3(0.34, -0.94, 0.08).normalized(),
			Vector3(-0.22, -0.97, -0.04).normalized(),
		]
		out["leg_b"] = [
			Vector3(-0.32, -0.95, -0.06).normalized(),
			Vector3(0.20, -0.98, 0.03).normalized(),
		]
	return out


static func _chain_lerp(a: Array, b: Array, weight: float) -> Array:
	return [
		(a[0] as Vector3).lerp(b[0], weight).normalized(),
		(a[1] as Vector3).lerp(b[1], weight).normalized(),
	]


static func _smooth(value: float) -> float:
	var x := clampf(value, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
