#include <amxmodx>
#include <amxmisc>
#include <reapi_stocks>


enum eWeaponType
{
	PRIMARY,
	SECONDARY
}
	
new g_szCommands[][] =
{
	"say /weapons",
	"say /weapon",
	"say_team /weapons",
	"say_team /weapon",
	"weapons",
	"say /gun",
	"say_team /gun",
	"say /guns",
	"say_team /guns",
	"guns"
}

new const g_szWeapons_FileName[] = "Huehue_Weapons_List"
new const g_szConfig_FileName[] = "Huehue_Weapons_Configuration"

enum Sections:eSections
{
	SECTION_PRIMARY,
	SECTION_SECONDARY,
	SECTION_BOT_PRIMARY,
	SECTION_BOT_SECONDARY
}

new Array:g_aWeapons_Short[eSections], Array:g_aWeapons_Menu[eSections], Array:g_aWeapons_Price[eSections], Array:g_aWeapons_VipFlag[eSections],
	Array:g_aWeapons_ViewSkin[eSections], Array:g_aWeapons_PlayerSkin[eSections]

new g_iWeapons[MAX_CLIENTS + 1][eWeaponType], g_iMenuUsedTimes[MAX_CLIENTS + 1]
new bool:g_bChoiceSaved[MAX_CLIENTS + 1], bool:g_bWeaponsPicked[MAX_CLIENTS + 1]

enum _:WMCvars
{
	HWM_ACTIVE,
	HWM_MIN_ROUND,
	HWM_MENU_CLOSE_OPTION,
	HWM_MENU_USES_PER_ROUND,
	Float:HWM_MENU_OPEN_AFTER,
	HWM_WHICH_TEAM_CAN_USE_MENU[12],
	Float:HWM_MENU_CLOSE_AFTER,
	HWM_WHICH_WEAPON_FIRST[22],
	HWM_VIP_FLAG[5],
	HWM_VIP_DISCOUNT[10],
	HWM_MAX_HE_NADES,
	HWM_RELOAD_WEAPONS,
	HWM_REFILL_WEAPONS_ON_RELOAD,
	HWM_GRENADES[12],
	HWM_FLASH_AMOUNT,
	HWM_HE_AMOUNT,
	HWM_SMOKE_AMOUNT,
	HWM_AUTOITEMS[12],
	Float:HWM_RESPAWN_TIME,
	HWM_DROP_WEAPONS,
	Float:HWM_PROTECTION_TIME,
	HWM_PROTECTION_COLORS_T[16],
	HWM_PROTECTION_COLORS_CT[16],
	HWM_INFINITE_ROUND,
	HWM_REMOVE_BOMB,
	HWM_REMOVE_BUYZONE,
	HWM_STRIP_WEAPONS_ON_SPAWN,
	HWM_REMOVE_C4_ITEM,
	HWM_REMOVE_WEAPONS_FROM_GROUND,
	HWM_ITEMS_STAY_ON_GROUND,
	HWM_GIVE_WEAPONS_TO_BOTS,
	HWM_MENU_COLOR_NUMBERS[15],
	HWM_CHAT_PREFIX[MAX_NAME_LENGTH],
	HWM_MENU_PREFIX[MAX_NAME_LENGTH]
}

new g_eCvars[WMCvars]

enum TeamName:eTeamColors
{
	NO_COLOR,
	TERRORIST_COLOR,
	CT_COLOR,
	NO_COLOR
}

enum _:eRGBA
{
	R, G, B, A
}

new g_eProtectionColors[eTeamColors][eRGBA]

const TASKID_DESTROY_MENU = 1914105
const TASKID_REOPEN_MENU = 1914106

const ARRAY_SIZE = 64

new bool:g_bFirstLoad

enum _:eMenuID
{
	EQUIP_ID,
	CHOOSE_ID,
	PRIMARY_ID,
	SECONDARY_ID
}
new g_iMenuIDs[eMenuID]

public plugin_init()
{
	register_plugin("[HWM] Huehue Weapon Menu", "1.0.5", "Huehue @ AMXX-BG.INFO")

	register_dictionary("hwm.txt")
	
	for (new i = 0; i < sizeof(g_szCommands); i++)
		register_clcmd(g_szCommands[i], "Weapons_Command")

	register_clcmd("drop", "Hook_DropCommand")

	register_clcmd("hwm_reload_file", "HWM_Reload_Weapons_File", ADMIN_RCON)

	bind_pcvar_num(create_cvar("hwm_active", "1", FCVAR_NONE, "Return info for additional mods if the plugin is active or not^nRequires 2 server restarts!", true, 0.0, true, 1.0), g_eCvars[HWM_ACTIVE])

	bind_pcvar_num(create_cvar("hwm_min_round", "0", FCVAR_NONE, "After which round to show the menu"), g_eCvars[HWM_MIN_ROUND])

	bind_pcvar_num(create_cvar("hwm_menu_close_option", "1", FCVAR_NONE, "Whether menu can be closed or not", true, 0.0, true, 1.0), g_eCvars[HWM_MENU_CLOSE_OPTION])
	bind_pcvar_num(create_cvar("hwm_menu_uses_per_round", "1", FCVAR_NONE, "How many times you can use the menu per round"), g_eCvars[HWM_MENU_USES_PER_ROUND])
	bind_pcvar_float(create_cvar("hwm_menu_open_after", "0.5", FCVAR_NONE, "How much seconds delay to open the menu^n0 = Open instantly on spawn", true, 0.0), g_eCvars[HWM_MENU_OPEN_AFTER])
	bind_pcvar_float(create_cvar("hwm_menu_close_after", "15.0", FCVAR_NONE, "After how many seconds weapons menu will be close"), g_eCvars[HWM_MENU_CLOSE_AFTER])

	bind_pcvar_string(create_cvar("hwm_menu_weapon_pick_order_first", "primary", FCVAR_NONE, "Which weapon to choose first^nprimary^nsecondary"), g_eCvars[HWM_WHICH_WEAPON_FIRST], charsmax(g_eCvars[HWM_WHICH_WEAPON_FIRST]))

	bind_pcvar_string(create_cvar("hwm_which_team_can_use_menu", "any", FCVAR_NONE, "Which team can use the menu:^nct = Counter-Terrorists^nt = Terrorists^nany = Both Teams can use it"), g_eCvars[HWM_WHICH_TEAM_CAN_USE_MENU], charsmax(g_eCvars[HWM_WHICH_TEAM_CAN_USE_MENU]))

	bind_pcvar_string(create_cvar("hwm_vip_flag", "b", FCVAR_NONE, "VIP Flag for discount"), g_eCvars[HWM_VIP_FLAG], charsmax(g_eCvars[HWM_VIP_FLAG]))
	bind_pcvar_string(create_cvar("hwm_vip_discount", "-35%", FCVAR_NONE, "How much % for vip discount when buy weapons"), g_eCvars[HWM_VIP_DISCOUNT], charsmax(g_eCvars[HWM_VIP_DISCOUNT]))

	bind_pcvar_num(create_cvar("hwm_max_he_player_can_have", "3", FCVAR_NONE, "How many HE Grenades player can have^nIf set to 0 it will disable it"), g_eCvars[HWM_MAX_HE_NADES])

	bind_pcvar_num(create_cvar("hwm_reload_weapons_on_kill", "1", FCVAR_NONE, "Instant reload weapons for VIP Players on every kill", true, 0.0, true, 1.0), g_eCvars[HWM_RELOAD_WEAPONS])
	bind_pcvar_num(create_cvar("hwm_refill_weapons_on_reload", "1", FCVAR_NONE, "Refill BPAmmo on every reload for the weapon player using", true, 0.0, true, 1.0), g_eCvars[HWM_REFILL_WEAPONS_ON_RELOAD])

	bind_pcvar_string(create_cvar("hwm_player_spawn_grenades", "fhs", FCVAR_NONE, "What grenade(s) player will receive on spawn^nf = flashbang^nh = he grenade^ns = smoke grenade"), g_eCvars[HWM_GRENADES], charsmax(g_eCvars[HWM_GRENADES]))
	bind_pcvar_string(create_cvar("hwm_player_auto_items", "ahg", FCVAR_NONE, "Items player will receive when they select weapons^na = armor^nh = helmet^ng = grenades^nd = defuse kit (CT's Only)^nn = night vision goggles"), g_eCvars[HWM_AUTOITEMS], charsmax(g_eCvars[HWM_AUTOITEMS]))

	bind_pcvar_num(create_cvar("hwm_fb_grenade_amount", "1", FCVAR_NONE, "Amount of Flash Bangs"), g_eCvars[HWM_FLASH_AMOUNT])
	bind_pcvar_num(create_cvar("hwm_he_grenade_amount", "1", FCVAR_NONE, "Amount of HE Grenades"), g_eCvars[HWM_HE_AMOUNT])
	bind_pcvar_num(create_cvar("hwm_sg_grenade_amount", "1", FCVAR_NONE, "Amount of Smoke Grenades"), g_eCvars[HWM_SMOKE_AMOUNT])

	bind_pcvar_float(create_cvar("hwm_respawn_wait_time", "0.75", FCVAR_NONE, "Player Respawn after X time in seconds^n0 = disabled"), g_eCvars[HWM_RESPAWN_TIME])

	bind_pcvar_num(create_cvar("hwm_no_drop_weapons", "1", FCVAR_NONE, "Whether players can drop weapons or not^n0 = they can^n1 = they cannot", true, 0.0, true, 1.0), g_eCvars[HWM_DROP_WEAPONS])

	bind_pcvar_float(create_cvar("hwm_protection_time", "5.0", FCVAR_NONE, "Player protection time in seconds"), g_eCvars[HWM_PROTECTION_TIME])
	bind_pcvar_string(create_cvar("hwm_protection_colors_ct", "0 0 255 50", FCVAR_NONE, "Protection Glow effect colors^nColors are RRR GGG BBB AAA(BBB) Alha(Brightness)^nrandom = random color every time^n0 = disabled"), g_eCvars[HWM_PROTECTION_COLORS_CT], charsmax(g_eCvars[HWM_PROTECTION_COLORS_CT]))
	bind_pcvar_string(create_cvar("hwm_protection_colors_t", "255 0 0 50", FCVAR_NONE, "Protection Glow effect colors^nColors are RRR GGG BBB AAA(BBB) Alha(Brightness)^nrandom = random color every time^n0 = disabled"), g_eCvars[HWM_PROTECTION_COLORS_T], charsmax(g_eCvars[HWM_PROTECTION_COLORS_T]))

	bind_pcvar_num(create_cvar("hwm_infinite_round", "1", FCVAR_NONE, "Whether the round be infinite or not", true, 0.0, true, 1.0), g_eCvars[HWM_INFINITE_ROUND])

	bind_pcvar_num(create_cvar("hwm_remove_bombzone", "1", FCVAR_NONE, "Whether map will have bomb zone or not", true, 0.0, true, 1.0), g_eCvars[HWM_REMOVE_BOMB])
	bind_pcvar_num(create_cvar("hwm_remove_buyzone", "1", FCVAR_NONE, "Whether map will have buy zone or not", true, 0.0, true, 1.0), g_eCvars[HWM_REMOVE_BUYZONE])

	bind_pcvar_num(create_cvar("hwm_strip_weapons_on_spawn", "1", FCVAR_NONE, "Remove all weapons from player on spawn", true, 0.0, true, 1.0), g_eCvars[HWM_STRIP_WEAPONS_ON_SPAWN])
	bind_pcvar_num(create_cvar("hwm_remove_bomb_spawn_player", "0", FCVAR_NONE, "Whether players will spawh with C4[Bomb] or not", true, 0.0, true, 1.0), g_eCvars[HWM_REMOVE_C4_ITEM])
	bind_pcvar_num(create_cvar("hwm_allow_weapons_place_on_map", "0", FCVAR_NONE, "Whether weapons placed on map be there or not^nfor example fy_snow.", true, 0.0, true, 1.0), g_eCvars[HWM_REMOVE_WEAPONS_FROM_GROUND])
	bind_pcvar_num(create_cvar("hwm_items_stay_on_ground", "0", FCVAR_NONE, "Whether weapons will be removed from ground after death^n1 = they will stay^n0 = they will be removed when player is killed", true, 0.0, true, 1.0), g_eCvars[HWM_ITEMS_STAY_ON_GROUND])
	bind_pcvar_num(create_cvar("hwm_give_weapons_to_bots", "1", FCVAR_NONE, "Give random weapon to bots", true, 0.0, true, 1.0), g_eCvars[HWM_GIVE_WEAPONS_TO_BOTS])

	bind_pcvar_string(create_cvar("hwm_menu_color_number", "\r", FCVAR_NONE, "\r = Red^n\y = Yellow^n\d = Grey^n\w = White"), g_eCvars[HWM_MENU_COLOR_NUMBERS], charsmax(g_eCvars[HWM_MENU_COLOR_NUMBERS]))
	bind_pcvar_string(create_cvar("hwm_menu_prefix", "\r[\yHWM\r]", FCVAR_NONE, "Menu prefix for the Menus^nColors are: \r | \y | \w | \d"), g_eCvars[HWM_MENU_PREFIX], charsmax(g_eCvars[HWM_MENU_PREFIX]))
	bind_pcvar_string(create_cvar("hwm_chat_prefix", "!y[!gHWM!y]", FCVAR_NONE, "Chat Prefix for the messages^nColors are: !y / !n | !g | !t"), g_eCvars[HWM_CHAT_PREFIX], charsmax(g_eCvars[HWM_CHAT_PREFIX]))

	AutoExecConfig(true, g_szConfig_FileName, "Huehue_WeaponMenu")
	
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn", true) // post func
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed", true) // post func
	RegisterHookChain(RG_CBasePlayer_RoundRespawn, "CBasePlayer_RoundRespawn", false) // pre func
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound", false) // pre func

	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "CBasePlayerWeapon_DefaultDeploy", false) // pre func

	RegisterHookChain(RG_CBasePlayer_SetSpawnProtection, "CBasePlayer_SetSpawnProtection", false) // pre func
	RegisterHookChain(RG_CBasePlayer_RemoveSpawnProtection, "CBasePlayer_RemoveSpawnProtection", false) // pre func

	g_bFirstLoad = false

	if (!g_eCvars[HWM_ACTIVE])
		pause("ad")
}

public plugin_natives()
{
	register_native("hwm_open_weapons_menu", "_hwm_open_weapons_menu")
}

// native hwm_open_weapons_menu(id);
public _hwm_open_weapons_menu(iPlugin, iParams)
{
	enum
	{
		arg_index = 1
	}

	new id = get_param(arg_index)

	return Toggle_Equip_PlayerCheck(id)
}

public OnAutoConfigsBuffered()
{
	AutoConfigInit()
}

public OnConfigsExecuted()
{
	AutoConfigInit()
}

AutoConfigInit()
{
	replace_all(g_eCvars[HWM_CHAT_PREFIX], charsmax(g_eCvars[HWM_CHAT_PREFIX]), "!y", "^1")
	replace_all(g_eCvars[HWM_CHAT_PREFIX], charsmax(g_eCvars[HWM_CHAT_PREFIX]), "!n", "^1")
	replace_all(g_eCvars[HWM_CHAT_PREFIX], charsmax(g_eCvars[HWM_CHAT_PREFIX]), "!t", "^3")
	replace_all(g_eCvars[HWM_CHAT_PREFIX], charsmax(g_eCvars[HWM_CHAT_PREFIX]), "!g", "^4")

	set_cvar_num("mp_refill_bpammo_weapons", g_eCvars[HWM_REFILL_WEAPONS_ON_RELOAD] ? 3 : 0)

	set_cvar_num("mp_round_infinite", g_eCvars[HWM_INFINITE_ROUND])

	set_cvar_float("mp_forcerespawn", g_eCvars[HWM_RESPAWN_TIME])

	set_cvar_float("mp_respawn_immunitytime", g_eCvars[HWM_PROTECTION_TIME])
	set_cvar_num("mp_respawn_immunity_effects", g_eCvars[HWM_PROTECTION_TIME] > 0.0 ? 1 : 0)
	set_cvar_num("mp_respawn_immunity_force_unset", g_eCvars[HWM_PROTECTION_TIME] > 0.0 ? 1 : 0)

	set_cvar_num("mp_item_staytime", g_eCvars[HWM_ITEMS_STAY_ON_GROUND] ? 300 : 0)

	set_cvar_num("mp_give_player_c4", g_eCvars[HWM_REMOVE_C4_ITEM])
	set_cvar_num("mp_weapons_allow_map_placed", g_eCvars[HWM_REMOVE_WEAPONS_FROM_GROUND])

	if (!g_bFirstLoad && g_eCvars[HWM_REMOVE_WEAPONS_FROM_GROUND])
	{
		g_bFirstLoad = true
		server_cmd("sv_restartround 1")
	}

	set_member_game(m_bMapHasBombTarget, g_eCvars[HWM_REMOVE_BOMB] ? false : true)
	set_member_game(m_bMapHasBombZone, g_eCvars[HWM_REMOVE_BOMB] ? false : true)

	rg_map_buy_status(g_eCvars[HWM_REMOVE_BUYZONE] ? false : true)

	GenerateProtectionColors()
}

public plugin_precache()
{
	for (new iSection = _:SECTION_PRIMARY; iSection <= _:SECTION_BOT_SECONDARY; iSection++)
	{
		g_aWeapons_Short[Sections:iSection] = ArrayCreate(ARRAY_SIZE, ARRAY_SIZE)
		g_aWeapons_Menu[Sections:iSection] = ArrayCreate(ARRAY_SIZE, ARRAY_SIZE)
		g_aWeapons_Price[Sections:iSection] = ArrayCreate(ARRAY_SIZE, ARRAY_SIZE)
		g_aWeapons_VipFlag[Sections:iSection] = ArrayCreate(ARRAY_SIZE, ARRAY_SIZE)
		g_aWeapons_ViewSkin[Sections:iSection] = ArrayCreate(ARRAY_SIZE, ARRAY_SIZE)
		g_aWeapons_PlayerSkin[Sections:iSection] = ArrayCreate(ARRAY_SIZE, ARRAY_SIZE)
	}

	UTIL_Load_Weapons_File(false)
}

public client_putinserver(id)
{
	g_iWeapons[id][PRIMARY] = -1
	g_iWeapons[id][SECONDARY] = -1
	g_bChoiceSaved[id] = false
	g_iMenuUsedTimes[id] = 0
	g_bWeaponsPicked[id] = false
}

public client_disconnected(id)
{
	if (task_exists(id + TASKID_DESTROY_MENU))
		remove_task(id + TASKID_DESTROY_MENU)

	if (task_exists(id + TASKID_REOPEN_MENU))
		remove_task(id + TASKID_REOPEN_MENU)
}

public CBasePlayer_Spawn(id)
{	
	if (is_user_alive(id))
	{
		if (g_eCvars[HWM_INFINITE_ROUND] || get_member_game(m_iTotalRoundsPlayed) >= g_eCvars[HWM_MIN_ROUND])
		{
			g_bWeaponsPicked[id] = false

			if (g_eCvars[HWM_INFINITE_ROUND])
				g_iMenuUsedTimes[id] = 0

			if (g_eCvars[HWM_STRIP_WEAPONS_ON_SPAWN])
			{
				rg_remove_all_items(id)
				rg_give_item(id, "weapon_knife")

				if (rg_has_item_by_name(id, "weapon_c4")) // Safecase should never happen..
					rg_remove_item(id, "weapon_c4")
			}

			if (!is_user_bot(id))
			{
				if (!is_in_menu(id))
				{
					if (g_eCvars[HWM_MENU_OPEN_AFTER] > 0)
						set_task(g_eCvars[HWM_MENU_OPEN_AFTER], "Toggle_Equip_PlayerCheck", id)
					else
						Toggle_Equip_PlayerCheck(id)
				}

				set_task_ex(1.0, "UTIL_CheckPlayer_Menu", id + TASKID_REOPEN_MENU, .flags = SetTask_Repeat)
			}

			if (is_user_bot(id) && g_eCvars[HWM_GIVE_WEAPONS_TO_BOTS])
			{
				static szWeaponShort[eWeaponType][MAX_NAME_LENGTH], iWeapon[eWeaponType], iArraySize[eSections], iRandomWeaponID[eWeaponType], i

				iArraySize[SECTION_BOT_PRIMARY] = ArraySize(Array:g_aWeapons_Short[SECTION_BOT_PRIMARY])
				iArraySize[SECTION_BOT_SECONDARY] = ArraySize(Array:g_aWeapons_Short[SECTION_BOT_SECONDARY])

				iRandomWeaponID[PRIMARY] = random_num(0, iArraySize[SECTION_BOT_PRIMARY] - 1)
				iRandomWeaponID[SECONDARY] = random_num(0, iArraySize[SECTION_BOT_SECONDARY] - 1)

				iWeapon[PRIMARY] = iRandomWeaponID[PRIMARY]

				i = 0
				while (i < 10)
				{
					iRandomWeaponID[PRIMARY]++

					if (iRandomWeaponID[PRIMARY] >= iArraySize[SECTION_BOT_PRIMARY])
						iRandomWeaponID[PRIMARY] = 0

					iWeapon[PRIMARY] = iRandomWeaponID[PRIMARY]
					i++
				}

				iWeapon[SECONDARY] = iRandomWeaponID[SECONDARY]
				i = 0
				while (i < 10)
				{
					iRandomWeaponID[SECONDARY]++

					if (iRandomWeaponID[SECONDARY] >= iArraySize[SECTION_BOT_SECONDARY])
						iRandomWeaponID[SECONDARY] = 0

					iWeapon[SECONDARY] = iRandomWeaponID[SECONDARY]
					i++
				}

				g_iWeapons[id][PRIMARY] = iRandomWeaponID[PRIMARY]
				g_iWeapons[id][SECONDARY] = iRandomWeaponID[SECONDARY]

				ArrayGetString(Array:g_aWeapons_Short[SECTION_BOT_PRIMARY], g_iWeapons[id][PRIMARY], szWeaponShort[PRIMARY], charsmax(szWeaponShort[]))
				ArrayGetString(Array:g_aWeapons_Short[SECTION_BOT_SECONDARY], g_iWeapons[id][SECONDARY], szWeaponShort[SECONDARY], charsmax(szWeaponShort[]))

				rg_give_item_ex(id, szWeaponShort[PRIMARY], GT_APPEND, -1, -1)
				rg_give_item_ex(id, szWeaponShort[SECONDARY], GT_APPEND, -1, -1)
			}
		}
	}
}

public UTIL_CheckPlayer_Menu(id)
{
	id -= TASKID_REOPEN_MENU

	if (!is_user_connected(id))
	{
		if (task_exists(id + TASKID_REOPEN_MENU))
			remove_task(id + TASKID_REOPEN_MENU)
		return
	}

	if (is_in_menu(id) && !is_weapons_menu(id))
	{
		if (task_exists(id + TASKID_DESTROY_MENU))
			remove_task(id + TASKID_DESTROY_MENU)

		return
	}

	if (!g_bWeaponsPicked[id] && !is_in_menu(id))
	{
		Toggle_Equip_PlayerCheck(id)
	}
}

public CBasePlayer_Killed(iVictim, iKiller, iShouldGib)
{
	if (iVictim == iKiller || !is_user_connected(iKiller))
		return HC_CONTINUE

	if (get_member(iVictim, m_bHeadshotKilled) && g_eCvars[HWM_MAX_HE_NADES] != 0)
		rg_give_item_ex(iKiller, "weapon_hegrenade", GT_APPEND, .bpammo = clamp(rg_get_user_bpammo(iKiller, WEAPON_HEGRENADE) + 1, rg_get_user_bpammo(iKiller, WEAPON_HEGRENADE), g_eCvars[HWM_MAX_HE_NADES]))

	if (is_user_vip(iKiller) && g_eCvars[HWM_RELOAD_WEAPONS])
	{
		new pActiveItem = get_member(iKiller, m_pActiveItem)

		if (is_nullent(pActiveItem) || rg_get_iteminfo(pActiveItem, ItemInfo_iMaxClip) == -1)
			return HC_CONTINUE

		rg_instant_reload_weapons(iKiller, pActiveItem)
	}

	return HC_CONTINUE
}

public CBasePlayer_SetSpawnProtection(id, Float:flTime)
{
	if (g_eCvars[HWM_PROTECTION_TIME] > 0.0)
	{
		if (equal(g_eCvars[HWM_PROTECTION_COLORS_CT], "random") || equal(g_eCvars[HWM_PROTECTION_COLORS_T], "random"))
			GenerateProtectionColors()

		static TeamName:iTeam
		iTeam = rg_get_user_team(id)
		rg_set_user_rendering_ex(id, kRenderFxGlowShell, g_eProtectionColors[iTeam][R], g_eProtectionColors[iTeam][G], g_eProtectionColors[iTeam][B], kRenderNormal, g_eProtectionColors[iTeam][A])
	}
}
public CBasePlayer_RemoveSpawnProtection(id)
{
	rg_set_user_rendering_ex(id)
}

public CSGameRules_RestartRound()
{
	if (g_eCvars[HWM_INFINITE_ROUND] && get_member_game(m_bCompleteReset))
	{
		set_member_game(m_iTotalRoundsPlayed, get_member_game(m_iTotalRoundsPlayed) + 1)
	}
}

public CBasePlayer_RoundRespawn(id)
{
	g_iMenuUsedTimes[id] = 0
}

public CBasePlayerWeapon_DefaultDeploy(const iItem, szViewModel[], szWeaponModel[], iAnim, szAnimExt[], iSkipLocal)
{
	if (is_nullent(iItem))
		return HC_CONTINUE

	static id, pActiveItem, szWeaponShort[eWeaponType][MAX_NAME_LENGTH], szWeaponViewModel[eWeaponType][64], szWeaponPlayerModel[eWeaponType][64]
	new WeaponIdType:w_iId
	id = get_member(iItem, m_pPlayer)
	pActiveItem = get_member(id, m_pActiveItem)

	if (is_user_bot(id))
		return HC_CONTINUE

	if (!is_nullent(pActiveItem))
	{
		if (rg_is_grenade_weapon_id(rg_get_user_active_weapon(id)) || rg_get_user_active_weapon(id) == WEAPON_KNIFE
			|| g_iWeapons[id][PRIMARY] == -1 || g_iWeapons[id][SECONDARY] == -1)
			return HC_CONTINUE
	}

	if (!is_nullent(pActiveItem) && rg_is_primary_weapon_id(rg_get_user_active_weapon(id)))
	{
		ArrayGetString(Array:g_aWeapons_Short[SECTION_PRIMARY], g_iWeapons[id][PRIMARY], szWeaponShort[PRIMARY], charsmax(szWeaponShort[]))

		w_iId = rg_get_weapon_info(szWeaponShort[PRIMARY], WI_ID)

		if (rg_get_user_active_weapon(id) == w_iId)
		{
			ArrayGetString(Array:g_aWeapons_ViewSkin[SECTION_PRIMARY], g_iWeapons[id][PRIMARY], szWeaponViewModel[PRIMARY], charsmax(szWeaponViewModel[]))

			if (!equal(szWeaponViewModel[PRIMARY], "default"))
				SetHookChainArg(2, ATYPE_STRING, szWeaponViewModel[PRIMARY])
		}
		if (rg_get_user_active_weapon(id) == w_iId)
		{
			ArrayGetString(Array:g_aWeapons_PlayerSkin[SECTION_PRIMARY], g_iWeapons[id][PRIMARY], szWeaponPlayerModel[PRIMARY], charsmax(szWeaponPlayerModel[]))

			if (!equal(szWeaponPlayerModel[PRIMARY], "default"))
				SetHookChainArg(3, ATYPE_STRING, szWeaponPlayerModel[PRIMARY])
		}
	}
	else if (!is_nullent(pActiveItem) && rg_is_secondary_weapon_id(rg_get_user_active_weapon(id)))
	{
		ArrayGetString(Array:g_aWeapons_Short[SECTION_SECONDARY], g_iWeapons[id][SECONDARY], szWeaponShort[SECONDARY], charsmax(szWeaponShort[]))

		w_iId = rg_get_weapon_info(szWeaponShort[SECONDARY], WI_ID)

		if (rg_get_user_active_weapon(id) == w_iId)
		{
			ArrayGetString(Array:g_aWeapons_ViewSkin[SECTION_SECONDARY], g_iWeapons[id][SECONDARY], szWeaponViewModel[SECONDARY], charsmax(szWeaponViewModel[]))

			if (!equal(szWeaponViewModel[SECONDARY], "default"))
				SetHookChainArg(2, ATYPE_STRING, szWeaponViewModel[SECONDARY])
		}
		if (rg_get_user_active_weapon(id) == w_iId)
		{
			ArrayGetString(Array:g_aWeapons_PlayerSkin[SECTION_SECONDARY], g_iWeapons[id][SECONDARY], szWeaponPlayerModel[SECONDARY], charsmax(szWeaponPlayerModel[]))

			if (!equal(szWeaponPlayerModel[SECONDARY], "default"))
				SetHookChainArg(3, ATYPE_STRING, szWeaponPlayerModel[SECONDARY])
		}
	}
	return HC_CONTINUE
}

public HWM_Reload_Weapons_File(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED

	for (new iSection = _:SECTION_PRIMARY; iSection <= _:SECTION_SECONDARY; iSection++)
	{
		ArrayClear(g_aWeapons_Short[Sections:iSection])
		ArrayClear(g_aWeapons_Menu[Sections:iSection])
		ArrayClear(g_aWeapons_Price[Sections:iSection])
		ArrayClear(g_aWeapons_VipFlag[Sections:iSection])
	}

	UTIL_Load_Weapons_File(true)

	console_print(id, "%L", id, "HWM_RELOAD_INI_FILE", g_szWeapons_FileName)
	return PLUGIN_HANDLED
}

public Hook_DropCommand(id)
{
	if (g_eCvars[HWM_DROP_WEAPONS])
		return PLUGIN_HANDLED

	return PLUGIN_CONTINUE
}

public Weapons_Command(id)
{
	if (!g_bChoiceSaved[id] && g_iMenuUsedTimes[id] > g_eCvars[HWM_MENU_USES_PER_ROUND])
	{
		client_print_color_ex(id, "%L", id, g_eCvars[HWM_INFINITE_ROUND] == 1 ? "HWM_GUNS_ALREADY_ENABLED_RESPAWN" : "HWM_GUNS_ALREADY_ENABLED_ROUND")
		return PLUGIN_HANDLED
	}

	if (g_eCvars[HWM_INFINITE_ROUND] || get_member_game(m_iTotalRoundsPlayed) >= g_eCvars[HWM_MIN_ROUND])
	{
		static p_iId, s_iId
		p_iId = g_iWeapons[id][PRIMARY]
		s_iId = g_iWeapons[id][SECONDARY]

		if (p_iId == -1 && s_iId == -1)
		{
			client_print(id, print_center, "%L", id, "HWM_SELECT_YOUR_WEAPONS_FIRST")

			if (!rg_user_has_primary(id) || !rg_user_has_secondary(id))
			{
				rg_remove_all_items(id, false)
				Toggle_Equip_PlayerCheck(id)
			}
			return PLUGIN_HANDLED
		}

		static iWeaponPrice[eWeaponType], szWeaponShort[eWeaponType][MAX_NAME_LENGTH]
		iWeaponPrice[PRIMARY] = ArrayGetCell(Array:g_aWeapons_Price[SECTION_PRIMARY], p_iId)
		iWeaponPrice[SECONDARY] = ArrayGetCell(Array:g_aWeapons_Price[SECTION_SECONDARY], s_iId)

		ArrayGetString(Array:g_aWeapons_Short[SECTION_PRIMARY], p_iId, szWeaponShort[PRIMARY], charsmax(szWeaponShort[]))
		ArrayGetString(Array:g_aWeapons_Short[SECTION_SECONDARY], s_iId, szWeaponShort[SECONDARY], charsmax(szWeaponShort[]))

		static iTotalPrice, iPlayerHaveEnoughMoney[eWeaponType]
		iTotalPrice = 0

		if (iWeaponPrice[PRIMARY] > 0 || iWeaponPrice[SECONDARY] > 0)
		{
			if (!is_user_flagged(id, p_iId, SECTION_PRIMARY) || !is_user_flagged(id, s_iId, SECTION_SECONDARY))
			{
				if (is_user_vip(id))
				{
					iPlayerHaveEnoughMoney[PRIMARY] = discount_math_fix(iWeaponPrice[PRIMARY], g_eCvars[HWM_VIP_DISCOUNT])
					iPlayerHaveEnoughMoney[SECONDARY] = discount_math_fix(iWeaponPrice[SECONDARY], g_eCvars[HWM_VIP_DISCOUNT])
				}
				else
				{
					iPlayerHaveEnoughMoney[PRIMARY] = iWeaponPrice[PRIMARY]
					iPlayerHaveEnoughMoney[SECONDARY] = iWeaponPrice[SECONDARY]
				}
			}
			iTotalPrice = iPlayerHaveEnoughMoney[PRIMARY] + iPlayerHaveEnoughMoney[SECONDARY]
			rg_give_user_money(id, iTotalPrice, true)
		}

		if (g_bChoiceSaved[id])
		{
			g_bChoiceSaved[id] = false
			client_print_color_ex(id, "%L", id, "HWM_RE_ENABLED_WEAPONS_MENU")

			if (g_iMenuUsedTimes[id] > g_eCvars[HWM_MENU_USES_PER_ROUND])
			{
				client_print_color_ex(id, "%L", id, "HWM_EQUIP_AVAILABLE_ON_NEW_SPAWN")
				Toggle_Equip_PlayerCheck(id)
				return PLUGIN_HANDLED
			}
		}
		else
		{
			client_print_color_ex(id, "%L", id, "HWM_RE_OPEN_WEAPONS_MENU")
		}

		rg_remove_all_items(id, false)

		g_bWeaponsPicked[id] = false

		Toggle_Equip_PlayerCheck(id)
	}
	return PLUGIN_HANDLED
}

public Toggle_Equip_PlayerCheck(id)
{
	if (!is_user_alive(id))
		return PLUGIN_HANDLED

	if (!equal(g_eCvars[HWM_WHICH_TEAM_CAN_USE_MENU], "any") && TEAM_TERRORIST < rg_get_user_team(id) < TEAM_CT
		|| equal(g_eCvars[HWM_WHICH_TEAM_CAN_USE_MENU], "ct") && rg_get_user_team(id) != TEAM_CT
		|| equal(g_eCvars[HWM_WHICH_TEAM_CAN_USE_MENU], "t") && rg_get_user_team(id) != TEAM_TERRORIST)
		return PLUGIN_HANDLED

	if (!rg_has_item_by_name(id, "weapon_knife"))
		rg_give_item(id, "weapon_knife")

	if (g_bChoiceSaved[id])
	{
		give_player_items(id)
	}
	else
	{
		if (g_iMenuUsedTimes[id] <= g_eCvars[HWM_MENU_USES_PER_ROUND])
			Show_Equip_Menu(id)
	}
	
	return PLUGIN_HANDLED
}

Show_Equip_Menu(id)
{
	if (g_iMenuUsedTimes[id] > g_eCvars[HWM_MENU_USES_PER_ROUND] || !is_user_alive(id))
		return

	g_iMenuIDs[EQUIP_ID] = menu_create(fmt("%s %L", g_eCvars[HWM_MENU_PREFIX], id, "HWM_EQUIP_MENU_TITLE"), "ChooseMenu_Handler")
	new iMenuCallBack = menu_makecallback("MainMenu_CallBack")

	static szWeaponMenuName[eWeaponType][MAX_NAME_LENGTH], p_iId, s_iId, szTempWeaponName[eWeaponType][MAX_NAME_LENGTH]
	p_iId = g_iWeapons[id][PRIMARY]
	s_iId = g_iWeapons[id][SECONDARY]

	menu_additem(g_iMenuIDs[EQUIP_ID], fmt("%L", id, "HWM_NEW_WEAPONS"))

	if (p_iId != -1 && s_iId != -1)
	{
		ArrayGetString(Array:g_aWeapons_Menu[SECTION_PRIMARY], p_iId, szWeaponMenuName[PRIMARY], charsmax(szWeaponMenuName[]))
		ArrayGetString(Array:g_aWeapons_Menu[SECTION_SECONDARY], s_iId, szWeaponMenuName[SECONDARY], charsmax(szWeaponMenuName[]))

		copy(szTempWeaponName[PRIMARY], charsmax(szTempWeaponName[]), szWeaponMenuName[PRIMARY])
		copy(szTempWeaponName[SECONDARY], charsmax(szTempWeaponName[]), szWeaponMenuName[SECONDARY])

		replace_menu_chars(szTempWeaponName[PRIMARY])
		replace_menu_chars(szTempWeaponName[SECONDARY])

		menu_additem(g_iMenuIDs[EQUIP_ID], fmt("%L", id, "HWM_PREVIOUS_WEAPONS_SELECTED", szTempWeaponName[PRIMARY], szTempWeaponName[SECONDARY]), .callback = iMenuCallBack)
	}
	else
	{
		menu_additem(g_iMenuIDs[EQUIP_ID], fmt("%L", id, "HWM_PREVIOUS_WEAPONS_NOT_SELECTED"), .callback = iMenuCallBack)
	}

	menu_additem(g_iMenuIDs[EQUIP_ID], fmt("%L", id, "HWM_DONT_SHOW_AGAIN_SELECTED"), .callback = iMenuCallBack)

	menu_setprop(g_iMenuIDs[EQUIP_ID], MPROP_NUMBER_COLOR, g_eCvars[HWM_MENU_COLOR_NUMBERS])

	if (!g_eCvars[HWM_MENU_CLOSE_OPTION])
		menu_setprop(g_iMenuIDs[EQUIP_ID], MPROP_EXIT, MEXIT_NEVER)
	
	if (g_eCvars[HWM_MENU_CLOSE_AFTER] > 0.0)
	{
		menu_display(id, g_iMenuIDs[EQUIP_ID], 0, floatround(g_eCvars[HWM_MENU_CLOSE_AFTER]))

		if (task_exists(id + TASKID_DESTROY_MENU))	
			change_task(id + TASKID_DESTROY_MENU, g_eCvars[HWM_MENU_CLOSE_AFTER])
		else
			set_task(g_eCvars[HWM_MENU_CLOSE_AFTER], "DestroyMenu", id + TASKID_DESTROY_MENU)
	}
	else
		menu_display(id, g_iMenuIDs[EQUIP_ID])
}

public MainMenu_CallBack(id, iMenu, Item)
{
	if (Item < 0 || g_iWeapons[id][PRIMARY] == -1 || g_iWeapons[id][SECONDARY] == -1)
	{
		menu_item_setname(iMenu, 2, fmt("%L", id, "HWM_DONT_SHOW_AGAIN_NOT_SELECTED"))
		return ITEM_DISABLED
	}

	return ITEM_ENABLED
}

public ChooseMenu_Handler(id, iMenu, Item)
{
	if (Item == MENU_EXIT || g_iMenuUsedTimes[id] > g_eCvars[HWM_MENU_USES_PER_ROUND] || !is_user_alive(id))
		return

	switch (Item)
	{
		case 0:
		{
			if (equal(g_eCvars[HWM_WHICH_WEAPON_FIRST], "primary"))
				ShowPrimaryWeapons(id)
			else if (equal(g_eCvars[HWM_WHICH_WEAPON_FIRST], "secondary"))
				ShowSecondaryWeapons(id)
			else
				log_amx("Pick 'primary' or 'secondary' for the menu!")
		}
		case 1: give_player_items(id)
		case 2:
		{
			give_player_items(id)
			g_bChoiceSaved[id] = true

			new const szChatCommands[][] = { "guns", "weapons", "gun", "weapon" }
			client_print_color_ex(id, "%L", id, "HWM_SAVE_CHOICE_INFO", szChatCommands[random_num(0, sizeof szChatCommands - 1)])
		}
	}
}

ShowWeaponsMenu(id)
{
	if (g_iMenuUsedTimes[id] > g_eCvars[HWM_MENU_USES_PER_ROUND] || !is_user_alive(id))
		return

	g_iMenuIDs[CHOOSE_ID] = menu_create(fmt("%s %L", g_eCvars[HWM_MENU_PREFIX], id, "HWM_CHOOSE_YOUR_WEAPONS_TITLE"), "WeaponsHandler")

	static szWeaponMenuName[eWeaponType][MAX_NAME_LENGTH], p_iId, s_iId, szTempWeaponName[eWeaponType][MAX_NAME_LENGTH]
	p_iId = g_iWeapons[id][PRIMARY]
	s_iId = g_iWeapons[id][SECONDARY]

	if (p_iId != -1 && s_iId != -1)
	{
		ArrayGetString(Array:g_aWeapons_Menu[SECTION_PRIMARY], p_iId, szWeaponMenuName[PRIMARY], charsmax(szWeaponMenuName[]))
		ArrayGetString(Array:g_aWeapons_Menu[SECTION_SECONDARY], s_iId, szWeaponMenuName[SECONDARY], charsmax(szWeaponMenuName[]))

		copy(szTempWeaponName[PRIMARY], charsmax(szTempWeaponName[]), szWeaponMenuName[PRIMARY])
		copy(szTempWeaponName[SECONDARY], charsmax(szTempWeaponName[]), szWeaponMenuName[SECONDARY])

		replace_menu_chars(szTempWeaponName[PRIMARY])
		replace_menu_chars(szTempWeaponName[SECONDARY])
	
		menu_additem(g_iMenuIDs[CHOOSE_ID], fmt("%L", id, "HWM_PRIMARY_WEAPON_SELECTED", szTempWeaponName[PRIMARY]))
		menu_additem(g_iMenuIDs[CHOOSE_ID], fmt("%L", id, "HWM_SECONDARY_WEAPON_SELECTED", szTempWeaponName[SECONDARY]))
	}
	else if (p_iId != -1 && s_iId == -1)
	{
		p_iId = g_iWeapons[id][PRIMARY]
		ArrayGetString(Array:g_aWeapons_Menu[SECTION_PRIMARY], p_iId, szWeaponMenuName[PRIMARY], charsmax(szWeaponMenuName[]))

		copy(szTempWeaponName[PRIMARY], charsmax(szTempWeaponName[]), szWeaponMenuName[PRIMARY])
		replace_menu_chars(szTempWeaponName[PRIMARY])

		menu_additem(g_iMenuIDs[CHOOSE_ID], fmt("%L", id, "HWM_PRIMARY_WEAPON_SELECTED", szTempWeaponName[PRIMARY]))
		menu_additem(g_iMenuIDs[CHOOSE_ID], fmt("%L", id, "HWM_SECONDARY_WEAPON_NOT_SELECTED"))
	}
	else if (p_iId == -1 && s_iId != -1)
	{
		s_iId = g_iWeapons[id][SECONDARY]
		ArrayGetString(Array:g_aWeapons_Menu[SECTION_SECONDARY], s_iId, szWeaponMenuName[SECONDARY], charsmax(szWeaponMenuName[]))

		copy(szTempWeaponName[SECONDARY], charsmax(szTempWeaponName[]), szWeaponMenuName[SECONDARY])
		replace_menu_chars(szTempWeaponName[SECONDARY])

		menu_additem(g_iMenuIDs[CHOOSE_ID], fmt("%L", id, "HWM_PRIMARY_WEAPON_NOT_SELECTED"))
		menu_additem(g_iMenuIDs[CHOOSE_ID], fmt("%L", id, "HWM_SECONDARY_WEAPON_SELECTED", szTempWeaponName[SECONDARY]))
	}
	else if (p_iId == -1 && s_iId == -1)
	{
		menu_additem(g_iMenuIDs[CHOOSE_ID], fmt("%L", id, "HWM_PRIMARY_WEAPON_NOT_SELECTED"))
		menu_additem(g_iMenuIDs[CHOOSE_ID], fmt("%L", id, "HWM_SECONDARY_WEAPON_NOT_SELECTED"))
	}

	menu_setprop(g_iMenuIDs[CHOOSE_ID], MPROP_NUMBER_COLOR, g_eCvars[HWM_MENU_COLOR_NUMBERS])
	
	if (!g_eCvars[HWM_MENU_CLOSE_OPTION])
		menu_setprop(g_iMenuIDs[CHOOSE_ID], MPROP_EXIT, MEXIT_NEVER)
	
	if (g_eCvars[HWM_MENU_CLOSE_AFTER] > 0.0)
	{
		menu_display(id, g_iMenuIDs[CHOOSE_ID], 0, floatround(g_eCvars[HWM_MENU_CLOSE_AFTER]))

		if (task_exists(id + TASKID_DESTROY_MENU))	
			change_task(id + TASKID_DESTROY_MENU, g_eCvars[HWM_MENU_CLOSE_AFTER])
		else
			set_task(g_eCvars[HWM_MENU_CLOSE_AFTER], "DestroyMenu", id + TASKID_DESTROY_MENU)
	}
	else
		menu_display(id, g_iMenuIDs[CHOOSE_ID])
}

public DestroyMenu(id)
{
	id -= TASKID_DESTROY_MENU

	if (is_user_connected(id))
	{
		show_menu(id, 0, "")

		if (task_exists(id + TASKID_DESTROY_MENU))
			remove_task(id + TASKID_DESTROY_MENU)
	}
}

public WeaponsHandler(id, iMenu, Item)
{
	if (Item == MENU_EXIT || g_iMenuUsedTimes[id] > g_eCvars[HWM_MENU_USES_PER_ROUND] || !is_user_alive(id))
		return
	
	switch (Item)
	{
		case 0: ShowPrimaryWeapons(id)
		case 1: ShowSecondaryWeapons(id)
	}
	
	menu_destroy(iMenu)
}

ShowPrimaryWeapons(id)
{
	g_iMenuIDs[PRIMARY_ID] = menu_create(fmt("%s %L", g_eCvars[HWM_MENU_PREFIX], id, "HWM_PRIMARY_WEAPON_TITLE"), "PrimaryHandler")

	static iWeaponPrice, szWeaponMenuName[MAX_NAME_LENGTH]

	for (new i = 0; i < ArraySize(Array:g_aWeapons_Short[SECTION_PRIMARY]); i++)
	{
		iWeaponPrice = ArrayGetCell(Array:g_aWeapons_Price[SECTION_PRIMARY], i)
		ArrayGetString(Array:g_aWeapons_Menu[SECTION_PRIMARY], i, szWeaponMenuName, charsmax(szWeaponMenuName))

		if (iWeaponPrice > 0 && !is_user_flagged(id, i, SECTION_PRIMARY))
			menu_additem(g_iMenuIDs[PRIMARY_ID], fmt("%L", id, "HWM_PRIMARY_WEAPON_PRICE_MENU", szWeaponMenuName, is_user_vip(id) ? discount_math_fix(iWeaponPrice, g_eCvars[HWM_VIP_DISCOUNT]) : iWeaponPrice))
		else if (is_user_flagged(id, i, SECTION_PRIMARY) || iWeaponPrice == 0)
			menu_additem(g_iMenuIDs[PRIMARY_ID], szWeaponMenuName)
	}

	menu_setprop(g_iMenuIDs[PRIMARY_ID], MPROP_NUMBER_COLOR, g_eCvars[HWM_MENU_COLOR_NUMBERS])

	if (!g_eCvars[HWM_MENU_CLOSE_OPTION])
		menu_setprop(g_iMenuIDs[PRIMARY_ID], MPROP_EXIT, MEXIT_NEVER)
	
	menu_display(id, g_iMenuIDs[PRIMARY_ID])
}

public PrimaryHandler(id, iMenu, Item)
{
	if (Item == MENU_EXIT)
	{
		ShowWeaponsMenu(id)
		return
	}

	static iWeaponPrice, iTotalPricePrim, iSecondaryPrice
	iWeaponPrice = ArrayGetCell(Array:g_aWeapons_Price[SECTION_PRIMARY], Item)

	if (g_iWeapons[id][SECONDARY] != -1)
		iSecondaryPrice = ArrayGetCell(Array:g_aWeapons_Price[SECTION_SECONDARY], g_iWeapons[id][SECONDARY])

	if (!is_user_flagged(id, Item, SECTION_PRIMARY))
	{
		if (g_iWeapons[id][SECONDARY] != -1)
		{
			if (iSecondaryPrice > 0)
			{
				static iPrices[2]
				iPrices[0] = is_user_vip(id) ? discount_math_fix(iWeaponPrice, g_eCvars[HWM_VIP_DISCOUNT]) : iWeaponPrice
				iPrices[1] = is_user_vip(id) ? discount_math_fix(iSecondaryPrice, g_eCvars[HWM_VIP_DISCOUNT]) : iSecondaryPrice
				iTotalPricePrim = iPrices[0] + iPrices[1]
			}
			else
				iTotalPricePrim = is_user_vip(id) ? discount_math_fix(iWeaponPrice, g_eCvars[HWM_VIP_DISCOUNT]) : iWeaponPrice
		}
		else
			iTotalPricePrim = is_user_vip(id) ? discount_math_fix(iWeaponPrice, g_eCvars[HWM_VIP_DISCOUNT]) : iWeaponPrice

		if (iTotalPricePrim > 0)
		{
			if (get_member(id, m_iAccount) < iTotalPricePrim)
			{
				client_print(id, print_center, "%L", id, "HWM_DONT_HAVE_ENOUGH_MONEY")
				ShowPrimaryWeapons(id)
				return
			}
		}
	}

	g_iWeapons[id][PRIMARY] = Item

	if (equal(g_eCvars[HWM_WHICH_WEAPON_FIRST], "primary"))
	{	
		menu_destroy(iMenu)
		ShowSecondaryWeapons(id)
	}
	else if (equal(g_eCvars[HWM_WHICH_WEAPON_FIRST], "secondary"))
	{
		if (g_iWeapons[id][SECONDARY] == -1)
		{
			ShowWeaponsMenu(id)
		}
		else
		{
			give_player_items(id)
			menu_destroy(iMenu)
		}
	}
}

ShowSecondaryWeapons(id)
{
	g_iMenuIDs[SECONDARY_ID] = menu_create(fmt("%s %L", g_eCvars[HWM_MENU_PREFIX], id, "HWM_SECONDARY_WEAPON_TITLE"), "SecondaryHandler")
	
	static iWeaponPrice, szWeaponMenuName[MAX_NAME_LENGTH]

	for (new i = 0; i < ArraySize(Array:g_aWeapons_Short[SECTION_SECONDARY]); i++)
	{
		iWeaponPrice = ArrayGetCell(Array:g_aWeapons_Price[SECTION_SECONDARY], i)
		ArrayGetString(Array:g_aWeapons_Menu[SECTION_SECONDARY], i, szWeaponMenuName, charsmax(szWeaponMenuName))

		if (iWeaponPrice > 0 && !is_user_flagged(id, i, SECTION_SECONDARY))
			menu_additem(g_iMenuIDs[SECONDARY_ID], fmt("%L", id, "HWM_SECONDARY_WEAPON_PRICE_MENU", szWeaponMenuName, is_user_vip(id) ? discount_math_fix(iWeaponPrice, g_eCvars[HWM_VIP_DISCOUNT]) : iWeaponPrice))
		else if (is_user_flagged(id, i, SECTION_SECONDARY) || iWeaponPrice == 0)
			menu_additem(g_iMenuIDs[SECONDARY_ID], szWeaponMenuName)
	}

	menu_setprop(g_iMenuIDs[SECONDARY_ID], MPROP_NUMBER_COLOR, g_eCvars[HWM_MENU_COLOR_NUMBERS])

	if (!g_eCvars[HWM_MENU_CLOSE_OPTION])
		menu_setprop(g_iMenuIDs[SECONDARY_ID], MPROP_EXIT, MEXIT_NEVER)

	menu_display(id, g_iMenuIDs[SECONDARY_ID])
}

public SecondaryHandler(id, iMenu, Item)
{
	if (Item == MENU_EXIT)
	{
		ShowWeaponsMenu(id)
		return
	}

	static iWeaponPrice, iTotalPriceSec, iPrimaryPrice
	iWeaponPrice = ArrayGetCell(Array:g_aWeapons_Price[SECTION_SECONDARY], Item)

	if (g_iWeapons[id][PRIMARY] != -1)
		iPrimaryPrice = ArrayGetCell(Array:g_aWeapons_Price[SECTION_PRIMARY], g_iWeapons[id][PRIMARY])

	if (!is_user_flagged(id, Item, SECTION_SECONDARY))
	{
		if (g_iWeapons[id][PRIMARY] != -1)
		{
			if (iPrimaryPrice > 0)
			{
				static iPrices[2]
				iPrices[0] = is_user_vip(id) ? discount_math_fix(iWeaponPrice, g_eCvars[HWM_VIP_DISCOUNT]) : iWeaponPrice
				iPrices[1] = is_user_vip(id) ? discount_math_fix(iPrimaryPrice, g_eCvars[HWM_VIP_DISCOUNT]) : iPrimaryPrice
				iTotalPriceSec = iPrices[0] + iPrices[1]
			}
			else
				iTotalPriceSec = is_user_vip(id) ? discount_math_fix(iWeaponPrice, g_eCvars[HWM_VIP_DISCOUNT]) : iWeaponPrice
		}
		else
			iTotalPriceSec = is_user_vip(id) ? discount_math_fix(iWeaponPrice, g_eCvars[HWM_VIP_DISCOUNT]) : iWeaponPrice

		if (iTotalPriceSec > 0)
		{
			if (get_member(id, m_iAccount) < iTotalPriceSec)
			{
				client_print(id, print_center, "%L", id, "HWM_DONT_HAVE_ENOUGH_MONEY")
				ShowSecondaryWeapons(id)
				return
			}
		}
	}
	g_iWeapons[id][SECONDARY] = Item

	if (equal(g_eCvars[HWM_WHICH_WEAPON_FIRST], "secondary"))
	{
		menu_destroy(iMenu)
		ShowPrimaryWeapons(id)
	}
	else if (equal(g_eCvars[HWM_WHICH_WEAPON_FIRST], "primary"))
	{
		if (g_iWeapons[id][PRIMARY] == -1)
		{
			ShowWeaponsMenu(id)
		}
		else
		{
			give_player_items(id)
			menu_destroy(iMenu)
		}
	}
}

UTIL_Load_Weapons_File(bool:bReloadFile)
{
	static szFileName[128], szData[512], iFilePointer
	
	get_localinfo("amxx_configsdir", szFileName, charsmax(szFileName))
	add(szFileName, charsmax(szFileName), fmt("/plugins/Huehue_WeaponMenu/%s.ini", g_szWeapons_FileName))
	
	if (!file_exists(szFileName))
	{
		server_print("Could not find %s.ini, creating new one..", g_szWeapons_FileName)
		iFilePointer = fopen(szFileName, "wt")

		if (iFilePointer)
		{
			new szFileDetails[2048]
			formatex(szFileDetails, charsmax(szFileDetails), "; To comment line use one of those symbols: # ; // ^n\
										; ^"weapon short name^" ^"weapon menu name^" WeaponPrice ^"flag/free/price^" ^"v_model^" ^"p_model^" ^n\
										; free -> free for everyone ^n\
										; price -> price for weapon for everyone including VIPs(they have it discounted) ^n\
										; flag ('d' example) -> Admin/VIP with flag 'd' receives weapon for free ^n\
										; Example: ^n\
										; ^"awp^" ^"AWP Magnum^" 4750 ^"d^" ^"models/ex_folder/v_awp.mdl^" ^"models/ex_folder/p_awp.mdl^" -> Players with flag 'd' will get it for free, other members like VIP will get it -% discount price setted by cvar & normal players will pay 4750 ^n^n\
										[PRIMARY]^n\
										^"m4a1^" ^"\w[\yM4A1\w]^" 0 ^"free^" ^"default^" ^"default^"^n\
										^"ak47^" ^"\w[\yAK47\w]^" 0 ^"free^" ^"default^" ^"default^" ^n\
										^"aug^" ^"AUG^" 0 ^"free^" ^"default^" ^"default^"^n\
										^"sg552^" ^"SG552^" 0 ^"free^" ^"default^" ^"default^"^n\
										^"galil^" ^"Galil^" 0 ^"free^" ^"default^" ^"default^"^n\
										^"famas^" ^"Famas^" 0 ^"free^" ^"default^" ^"default^"^n\
										^"scout^" ^"Scout^" 0 ^"free^" ^"default^" ^"default^"^n\
										^"awp^" ^"AWP^" 4750 ^"d^" ^"default^" ^"default^"^n\
										^"sg550^" ^"SG550^" 4200 ^"b^" ^"default^" ^"default^"^n\
										^"m249^" ^"M249^" 5750 ^"a^" ^"default^" ^"default^"^n\
										^"g3sg1^" ^"G3SG1^" 5000 ^"c^" ^"default^" ^"default^"^n\
										^"p90^" ^"P90^" 0 ^"free^" ^"default^" ^"default^"^n^n\
										[SECONDARY]^n\
										^"glock18^" ^"Glock 18^" 0 ^"free^" ^"default^" ^"default^"^n\
										^"usp^" ^"USP^" 0 ^"free^" ^"default^" ^"default^"^n\
										^"p228^" ^"P228^" 0 ^"free^" ^"default^" ^"default^"^n\
										^"deagle^" ^"\w[\yDeagle\w]^" 0 ^"free^" ^"default^" ^"default^"^n\
										^"fiveseven^" ^"FiveSeven^" 0 ^"free^" ^"default^" ^"default^"^n\
										^"elite^" ^"Elite Dual Batteras^" 0 ^"free^" ^"default^" ^"default^"^n^n\
										[BOT PRIMARY]^n\
										^"ak47^"^n\
										^"m4a1^"^n\
										^"galil^"^n\
										^"famas^"^n^n\
										[BOT SECONDARY]^n\
										^"glock18^"^n\
										^"usp^"^n\
										^"p228^"^n\
										^"deagle^"")
			fputs(iFilePointer, szFileDetails)
		}
		fclose(iFilePointer)
		UTIL_Load_Weapons_File(false)
		return
	}
	
	iFilePointer = fopen(szFileName,"rt+")
	
	if (!iFilePointer)
		return

	static Sections:iSection, szWeaponShort[MAX_NAME_LENGTH], szWeaponMenuName[MAX_NAME_LENGTH], szPrice[10], szVipFlag[10], szViewSkin[64], szPlayerSkin[64]
		
	while (!feof(iFilePointer))
	{
		fgets(iFilePointer, szData, charsmax(szData))
		trim(szData)

		switch(szData[0])
		{
			case EOS, ';', '#', '/': if (szData[1] == '/') continue; else continue
			case '[':
			{
				if (szData[strlen(szData) - 1] == ']')
				{
					if (containi(szData, "primary") != -1 && containi(szData, "bot") == -1)
						iSection = SECTION_PRIMARY
					else if (containi(szData, "secondary") != -1 && containi(szData, "bot") == -1)
						iSection = SECTION_SECONDARY
					else if (containi(szData, "bot primary") != -1)
						iSection = SECTION_BOT_PRIMARY
					else if (containi(szData, "bot secondary") != -1)
						iSection = SECTION_BOT_SECONDARY
				}
				else
					continue
			}
			default:
			{
				parse(szData, szWeaponShort, charsmax(szWeaponShort), szWeaponMenuName, charsmax(szWeaponMenuName), szPrice, charsmax(szPrice), szVipFlag, charsmax(szVipFlag),
					szViewSkin, charsmax(szViewSkin), szPlayerSkin, charsmax(szPlayerSkin))

				ArrayPushString(g_aWeapons_Short[iSection], fmt("weapon_%s", szWeaponShort))
				ArrayPushString(g_aWeapons_Menu[iSection], szWeaponMenuName)
				ArrayPushCell(g_aWeapons_Price[iSection], str_to_num(szPrice))
				ArrayPushString(g_aWeapons_VipFlag[iSection], szVipFlag)

				if (!bReloadFile)
				{
					if (file_exists(szViewSkin) && !equal(szViewSkin, "default"))
						precache_model(szViewSkin)

					ArrayPushString(g_aWeapons_ViewSkin[iSection], szViewSkin)

					if (file_exists(szPlayerSkin) && !equal(szPlayerSkin, "default"))
						precache_model(szPlayerSkin)

					ArrayPushString(g_aWeapons_PlayerSkin[iSection], szPlayerSkin)
				}
			}
		}
	}
	
	fclose(iFilePointer)
}

stock give_player_items(id)
{
	static p_iId, s_iId
	p_iId = g_iWeapons[id][PRIMARY]
	s_iId = g_iWeapons[id][SECONDARY]

	if (p_iId == -1 && s_iId == -1)
	{
		client_print(id, print_center, "%L", id, "HWM_SELECT_YOUR_WEAPONS_FIRST")
		ShowWeaponsMenu(id)
		return
	}

	static iWeaponPrice[eWeaponType], szWeaponShort[eWeaponType][MAX_NAME_LENGTH]
	iWeaponPrice[PRIMARY] = ArrayGetCell(Array:g_aWeapons_Price[SECTION_PRIMARY], p_iId)
	iWeaponPrice[SECONDARY] = ArrayGetCell(Array:g_aWeapons_Price[SECTION_SECONDARY], s_iId)

	ArrayGetString(Array:g_aWeapons_Short[SECTION_PRIMARY], p_iId, szWeaponShort[PRIMARY], charsmax(szWeaponShort[]))
	ArrayGetString(Array:g_aWeapons_Short[SECTION_SECONDARY], s_iId, szWeaponShort[SECONDARY], charsmax(szWeaponShort[]))

	static iTotalPrice, iPlayerHaveEnoughMoney[eWeaponType]
	iTotalPrice = 0

	if (!is_user_flagged(id, p_iId, SECTION_PRIMARY) || !is_user_flagged(id, s_iId, SECTION_SECONDARY))
	{
		if (is_user_vip(id))
		{
			iPlayerHaveEnoughMoney[PRIMARY] = discount_math_fix(iWeaponPrice[PRIMARY], g_eCvars[HWM_VIP_DISCOUNT])
			iPlayerHaveEnoughMoney[SECONDARY] = discount_math_fix(iWeaponPrice[SECONDARY], g_eCvars[HWM_VIP_DISCOUNT])
			iTotalPrice = iPlayerHaveEnoughMoney[PRIMARY] + iPlayerHaveEnoughMoney[SECONDARY]
		}
		else
		{
			iPlayerHaveEnoughMoney[PRIMARY] = iWeaponPrice[PRIMARY]
			iPlayerHaveEnoughMoney[SECONDARY] = iWeaponPrice[SECONDARY]
			iTotalPrice = iWeaponPrice[PRIMARY] + iWeaponPrice[SECONDARY]
		}
	}

	if (iTotalPrice > 0)
	{
		if (get_member(id, m_iAccount) < iPlayerHaveEnoughMoney[PRIMARY] || get_member(id, m_iAccount) < iPlayerHaveEnoughMoney[SECONDARY]
			|| get_member(id, m_iAccount) < iTotalPrice)
		{
			g_iWeapons[id][PRIMARY] = g_iWeapons[id][SECONDARY] = -1

			client_print(id, print_center, "%L", id, "HWM_DONT_HAVE_ENOUGH_MONEY")

			if (g_eCvars[HWM_MENU_CLOSE_AFTER] > 0.0 && task_exists(id + TASKID_DESTROY_MENU))
			{
				change_task(id + TASKID_DESTROY_MENU, g_eCvars[HWM_MENU_CLOSE_AFTER])
			}

			if (g_bChoiceSaved[id])
			{
				g_bChoiceSaved[id] = false
				Show_Equip_Menu(id)
				return
			}
			ShowWeaponsMenu(id)
			return
		}
	}
	
	rg_give_item_ex(id, szWeaponShort[PRIMARY], GT_APPEND, -1, -1)
	rg_give_item_ex(id, szWeaponShort[SECONDARY], GT_APPEND, -1, -1)

	if (contain(g_eCvars[HWM_AUTOITEMS], "a") != - 1)
	{
		if (contain(g_eCvars[HWM_AUTOITEMS], "h") != - 1)
			rg_set_user_armor(id, 100, ARMOR_VESTHELM)
		else
			rg_set_user_armor(id, 100, ARMOR_KEVLAR)
	}

	if (contain(g_eCvars[HWM_AUTOITEMS], "g") != -1)
	{
		if (contain(g_eCvars[HWM_GRENADES], "f") != -1)
			rg_give_item_ex(id, "weapon_flashbang", GT_APPEND, .bpammo = g_eCvars[HWM_FLASH_AMOUNT])

		if (contain(g_eCvars[HWM_GRENADES], "h") != -1)
			rg_give_item_ex(id, "weapon_hegrenade", GT_APPEND, .bpammo = g_eCvars[HWM_HE_AMOUNT])

		if (contain(g_eCvars[HWM_GRENADES], "s") != -1)
			rg_give_item_ex(id, "weapon_smokegrenade", GT_APPEND, .bpammo = g_eCvars[HWM_SMOKE_AMOUNT])
	}

	if (contain(g_eCvars[HWM_AUTOITEMS], "d") != - 1)
	{
		if (rg_get_user_team(id) == TEAM_CT)
			rg_give_defusekit(id, true)
	}

	if (contain(g_eCvars[HWM_AUTOITEMS], "n") != - 1)
	{
		rg_set_user_nvg(id, true)
	}
	
	g_iMenuUsedTimes[id]++
	g_bWeaponsPicked[id] = true

	if (task_exists(id + TASKID_DESTROY_MENU))
		remove_task(id + TASKID_DESTROY_MENU)

	rg_take_user_money(id, iTotalPrice, true)
}

stock bool:is_user_vip(id)
{
	if (get_user_flags (id) & read_flags(g_eCvars[HWM_VIP_FLAG]))
		return true

	return false
}

stock bool:is_user_flagged(id, iWeapon, Sections:iSection)
{
	static szFlag[10]
	ArrayGetArray(Array:g_aWeapons_VipFlag[iSection], iWeapon, szFlag, charsmax(szFlag))

	if (equal(szFlag, "free")
		|| !equal(szFlag, "free") && !equal(szFlag, "price") && get_user_flags(id) & read_flags(szFlag))
		return true
	else if (equal(szFlag, "price"))
		return false

	return false
}

replace_menu_chars(szChars[MAX_NAME_LENGTH])
{
	replace_all(szChars, charsmax(szChars), "\r", "")
	replace_all(szChars, charsmax(szChars), "\y", "")
	replace_all(szChars, charsmax(szChars), "\w", "")
	replace_all(szChars, charsmax(szChars), "\d", "")
	replace_all(szChars, charsmax(szChars), "]", "")
	replace_all(szChars, charsmax(szChars), "[", "")
	replace_all(szChars, charsmax(szChars), "{", "")
	replace_all(szChars, charsmax(szChars), "}", "")

	return szChars
}

GenerateProtectionColors()
{
	static szPlace[6]

	if (!equal(g_eCvars[HWM_PROTECTION_COLORS_CT], "0"))
	{
		if (equal(g_eCvars[HWM_PROTECTION_COLORS_CT], "random"))
		{
			g_eProtectionColors[TEAM_CT][R] = random(256)
			g_eProtectionColors[TEAM_CT][G] = random(256)
			g_eProtectionColors[TEAM_CT][B] = random(256)
			g_eProtectionColors[TEAM_CT][A] = random(256)
		}
		else
		{
			argbreak(g_eCvars[HWM_PROTECTION_COLORS_CT], szPlace, charsmax(szPlace), g_eCvars[HWM_PROTECTION_COLORS_CT], charsmax(g_eCvars[HWM_PROTECTION_COLORS_CT]))
			g_eProtectionColors[TEAM_CT][R] = str_to_num(szPlace)
			argbreak(g_eCvars[HWM_PROTECTION_COLORS_CT], szPlace, charsmax(szPlace), g_eCvars[HWM_PROTECTION_COLORS_CT], charsmax(g_eCvars[HWM_PROTECTION_COLORS_CT]))
			g_eProtectionColors[TEAM_CT][G] = str_to_num(szPlace)
			argbreak(g_eCvars[HWM_PROTECTION_COLORS_CT], szPlace, charsmax(szPlace), g_eCvars[HWM_PROTECTION_COLORS_CT], charsmax(g_eCvars[HWM_PROTECTION_COLORS_CT]))
			g_eProtectionColors[TEAM_CT][B] = str_to_num(szPlace)
			g_eProtectionColors[TEAM_CT][A] = str_to_num(g_eCvars[HWM_PROTECTION_COLORS_CT])
		}
	}

	if (!equal(g_eCvars[HWM_PROTECTION_COLORS_T], "0"))
	{
		if (equal(g_eCvars[HWM_PROTECTION_COLORS_T], "random"))
		{
			g_eProtectionColors[TEAM_TERRORIST][R] = random(256)
			g_eProtectionColors[TEAM_TERRORIST][G] = random(256)
			g_eProtectionColors[TEAM_TERRORIST][B] = random(256)
			g_eProtectionColors[TEAM_TERRORIST][A] = random(256)
		}
		else
		{
			argbreak(g_eCvars[HWM_PROTECTION_COLORS_T], szPlace, charsmax(szPlace), g_eCvars[HWM_PROTECTION_COLORS_T], charsmax(g_eCvars[HWM_PROTECTION_COLORS_T]))
			g_eProtectionColors[TEAM_TERRORIST][R] = str_to_num(szPlace)
			argbreak(g_eCvars[HWM_PROTECTION_COLORS_T], szPlace, charsmax(szPlace), g_eCvars[HWM_PROTECTION_COLORS_T], charsmax(g_eCvars[HWM_PROTECTION_COLORS_T]))
			g_eProtectionColors[TEAM_TERRORIST][G] = str_to_num(szPlace)
			argbreak(g_eCvars[HWM_PROTECTION_COLORS_T], szPlace, charsmax(szPlace), g_eCvars[HWM_PROTECTION_COLORS_T], charsmax(g_eCvars[HWM_PROTECTION_COLORS_T]))
			g_eProtectionColors[TEAM_TERRORIST][B] = str_to_num(szPlace)
			g_eProtectionColors[TEAM_TERRORIST][A] = str_to_num(g_eCvars[HWM_PROTECTION_COLORS_T])
		}
	}
}

stock client_print_color_ex(const pPlayer, const szInputMessage[], any:...)
{
	static szMessage[191]
	new iLen = formatex(szMessage, charsmax(szMessage), "%s ", g_eCvars[HWM_CHAT_PREFIX])
	vformat(szMessage[iLen], charsmax(szMessage) - iLen, szInputMessage, 3)
	client_print_color(pPlayer, print_team_default, szMessage)
}

stock is_in_menu(id)
{
	new iMenu, iNewMenu
	new bIsMenuActive = player_menu_info(id, iMenu, iNewMenu)

	if (bIsMenuActive || iMenu)
		return true

	return false
}

stock is_weapons_menu(id)
{
	new iMenu, iNewMenu
	player_menu_info(id, iMenu, iNewMenu)

	if (g_iMenuIDs[EQUIP_ID] <= iNewMenu <= g_iMenuIDs[SECONDARY_ID])
		return true

	return false
}