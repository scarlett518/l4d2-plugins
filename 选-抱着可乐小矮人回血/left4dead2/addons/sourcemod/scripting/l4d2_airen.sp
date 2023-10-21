#define PLUGIN_VERSION 		"1.1"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Healing Cola
*	Author	:	SilverShot
*	Descrp	:	Heals players with temporary or main health when they hold the Cola.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=181518

========================================================================================
	Change Log:

1.1 (01-Jul-2012)
	- Added cvars "l4d2_cola_glow" and "l4d2_cola_glow_color" to make the cola glow.
	- Fixed healing players above 100 HP.

1.0 (30-Mar-2012)
	- Initial release.

========================================================================================
	Thanks:

	This plugin was made using source code from the following plugins.
	If I have used your code and not credited you, please let me know.

*	"Zuko & McFlurry" for "[L4D2] Weapon/Zombie Spawner" - Modified SetTeleportEndPoint function.
	http://forums.alliedmods.net/showthread.php?t=109659

======================================================================================*/

#pragma semicolon 			1

#include <sourcemod>
#include <sdktools>

#define CVAR_FLAGS			FCVAR_PLUGIN|FCVAR_NOTIFY
#define CHAT_TAG			"\x04[\x05Cola\x04] \x01"
#define CONFIG_SPAWNS		"data/l4d2_cola.cfg"
#define MAX_COLAS			32

#define MODEL_COLA			"models/props_junk/gnome.mdl"


static	Handle:g_hCvarMPGameMode, Handle:g_hCvarModes, Handle:g_hCvarModesOff, Handle:g_hCvarModesTog, Handle:g_hCvarAllow,
		Handle:g_hCvarGlow, Handle:g_hCvarGlowCol, Handle:g_hCvarHeal, Handle:g_hCvarRandom, Handle:g_hCvarRate, Handle:g_hCvarSafe, Handle:g_hCvarTemp,
		bool:g_bCvarAllow, g_iCvarGlow, g_iCvarGlowCol, g_iCvarHeal, g_iCvarRandom, Float:g_fCvarRate, g_iCvarSafe, g_iCvarTemp,
		Handle:g_hCvarDecayRate, Float:g_fCvarDecayRate, Handle:g_hTimerHeal, Handle:g_hMenuAng, Handle:g_hMenuPos,
		bool:g_bLoaded, g_iMap, g_iPlayerSpawn, g_iRoundStart, g_iColaCount, g_iColas[MAX_COLAS][2], g_iCola[MAXPLAYERS+1], Float:g_fHealTime[MAXPLAYERS+1];



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin:myinfo =
{
	name = "[L4D2] Healing Cola",
	author = "SilverShot",
	description = "Heals players with temporary or main health when they hold the Cola.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=181518"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	decl String:sGameName[12];
	GetGameFolderName(sGameName, sizeof(sGameName));
	if( strcmp(sGameName, "left4dead2", false) )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public OnPluginStart()
{
	g_hCvarAllow =		CreateConVar(	"l4d2_cola_allow",		"1",			"0=插件关闭, 1=插件开启.", CVAR_FLAGS );
	g_hCvarGlow =		CreateConVar(	"l4d2_cola_glow",		"200",			"0=关, 设置最大距离发光的矮人.", CVAR_FLAGS );
	g_hCvarGlowCol =	CreateConVar(	"l4d2_cola_glow_color",	"255 255 255",	"0=默认发光颜色. 三个值0 - 255之间用空格分开. RGB: 红 绿 蓝.", CVAR_FLAGS );
	g_hCvarHeal =		CreateConVar(	"l4d2_cola_heal",		"1",			"0=关, 1=开 玩家抱着可乐.", CVAR_FLAGS );
	g_hCvarModes =		CreateConVar(	"l4d2_cola_modes",		"",				"打开插件在这些游戏模式, 用逗号分开 (不能有空格). (空白 = 全部).", CVAR_FLAGS );
	g_hCvarModesOff =	CreateConVar(	"l4d2_cola_modes_off",	"",				"关掉插件在这些游戏模式, 用逗号分开 (不能有空格). (空白 = 没有).", CVAR_FLAGS );
	g_hCvarModesTog =	CreateConVar(	"l4d2_cola_modes_tog",	"0",			"打开插件在这些游戏模式. 0=全部, 1=战役, 2=生存模式, 4=对抗, 8=清道夫.添加数字加起来.", CVAR_FLAGS );
	g_hCvarRandom =		CreateConVar(	"l4d2_cola_random",		"-1",			"-1=全部, 0=没有. 否则随机选择这许多矮人从地图配置产生.", CVAR_FLAGS );
	g_hCvarRate =		CreateConVar(	"l4d2_cola_rate",		"3",			"玩家每多少秒治愈多少HP .", CVAR_FLAGS );
	g_hCvarSafe =		CreateConVar(	"l4d2_cola_safe",		"1",			"在一轮开始产生了矮人: 0=关, 1=在安全室, 2=随即装备玩家.", CVAR_FLAGS );
	g_hCvarTemp =		CreateConVar(	"l4d2_cola_temp",		"-1",			"-1=添加临时的健康, 0=添加到主要的健康. 1和100之间的值创建一个机会给主要的健康, 否则将是临时健康.", CVAR_FLAGS );
	CreateConVar(						"l4d2_cola_version",	PLUGIN_VERSION, "愈合矮人的插件版本.", CVAR_FLAGS|FCVAR_REPLICATED|FCVAR_DONTRECORD);
	AutoExecConfig(true,				"l4d2_airen");

	g_hCvarDecayRate = FindConVar("pain_pills_decay_rate");
	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	HookConVarChange(g_hCvarMPGameMode,		ConVarChanged_Allow);
	HookConVarChange(g_hCvarAllow,			ConVarChanged_Allow);
	HookConVarChange(g_hCvarModes,			ConVarChanged_Allow);
	HookConVarChange(g_hCvarModesOff,		ConVarChanged_Allow);
	HookConVarChange(g_hCvarModesTog,		ConVarChanged_Allow);
	HookConVarChange(g_hCvarHeal,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarRandom,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarRate,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarSafe,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarTemp,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarDecayRate,		ConVarChanged_Cvars);

	RegAdminCmd("sm_cola",			CmdColaTemp,		ADMFLAG_ROOT, 	"生成一个临时的矮人在你的准心.");
	RegAdminCmd("sm_colasave",		CmdColaSave,		ADMFLAG_ROOT, 	"在你的准心产生一个矮人并保存到配置.");
	RegAdminCmd("sm_coladel",		CmdColaDelete,		ADMFLAG_ROOT, 	"删除矮人你指向和删除配置如果保存.");
	RegAdminCmd("sm_colawipe",		CmdColaWipe,		ADMFLAG_ROOT, 	"移除所有从当前地图和矮人删除它们从配置。.");
	RegAdminCmd("sm_colaglow",		CmdColaGlow,		ADMFLAG_ROOT, 	"切换到使发光所有矮人看到他们被放置.");
	RegAdminCmd("sm_colalist",		CmdColaList,		ADMFLAG_ROOT, 	"显示一个列表的位置和矮人的总数.");
	RegAdminCmd("sm_colatele",		CmdColaTele,		ADMFLAG_ROOT, 	"传送到一个矮人(用法: sm_colatele <index: 1 to MAX_COLAS>).");
	RegAdminCmd("sm_colaang",		CmdColaAng,			ADMFLAG_ROOT, 	"显示一个菜单来调整你的矮人角度准星掠过.");
	RegAdminCmd("sm_colapos",		CmdColaPos,			ADMFLAG_ROOT, 	"显示一个菜单来调整你的矮人起源准星掠过.");
}

public OnPluginEnd()
{
	ResetPlugin();
}

public OnMapStart()
{
	PrecacheModel(MODEL_COLA, true);
}

public OnMapEnd()
{
	g_iMap = 1;
	ResetPlugin(false);
}

GetColor(Handle:cvar)
{
	decl String:sTemp[12], String:sColors[3][4];
	GetConVarString(cvar, sTemp, sizeof(sTemp));
	ExplodeString(sTemp, " ", sColors, 3, 4);

	new color;
	color = StringToInt(sColors[0]);
	color += 256 * StringToInt(sColors[1]);
	color += 65536 * StringToInt(sColors[2]);
	return color;
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public OnConfigsExecuted()
	IsAllowed();

public ConVarChanged_Cvars(Handle:convar, const String:oldValue[], const String:newValue[])
	GetCvars();

public ConVarChanged_Allow(Handle:convar, const String:oldValue[], const String:newValue[])
	IsAllowed();

GetCvars()
{
	g_iCvarGlow = GetConVarInt(g_hCvarGlow);
	g_iCvarGlowCol = GetColor(g_hCvarGlowCol);
	g_iCvarHeal = GetConVarInt(g_hCvarHeal);
	g_iCvarRandom = GetConVarInt(g_hCvarRandom);
	g_fCvarRate = GetConVarFloat(g_hCvarRate);
	g_iCvarSafe = GetConVarInt(g_hCvarSafe);
	g_iCvarTemp = GetConVarInt(g_hCvarTemp);
	g_fCvarDecayRate = GetConVarFloat(g_hCvarDecayRate);
}

IsAllowed()
{
	new bool:bCvarAllow = GetConVarBool(g_hCvarAllow);
	new bool:bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		LoadColas();
		g_bCvarAllow = true;
		HookEvent("player_spawn",		Event_PlayerSpawn,	EventHookMode_PostNoCopy);
		HookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
		HookEvent("round_end",			Event_RoundEnd,		EventHookMode_PostNoCopy);
		HookEvent("item_pickup",		Event_ItemPickup);
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		ResetPlugin();
		g_bCvarAllow = false;
		UnhookEvent("player_spawn",		Event_PlayerSpawn,	EventHookMode_PostNoCopy);
		UnhookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
		UnhookEvent("round_end",		Event_RoundEnd,		EventHookMode_PostNoCopy);
		UnhookEvent("item_pickup",		Event_ItemPickup);
	}
}

static g_iCurrentMode;

bool:IsAllowedGameMode()
{
	if( g_hCvarMPGameMode == INVALID_HANDLE )
		return false;

	new iCvarModesTog = GetConVarInt(g_hCvarModesTog);
	if( iCvarModesTog != 0 )
	{
		g_iCurrentMode = 0;

		new entity = CreateEntityByName("info_gamemode");
		DispatchSpawn(entity);
		HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
		AcceptEntityInput(entity, "PostSpawnActivate");
		AcceptEntityInput(entity, "Kill");

		if( g_iCurrentMode == 0 )
			return false;

		if( !(iCvarModesTog & g_iCurrentMode) )
			return false;
	}

	decl String:sGameModes[64], String:sGameMode[64];
	GetConVarString(g_hCvarMPGameMode, sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	GetConVarString(g_hCvarModes, sGameModes, sizeof(sGameModes));
	if( strcmp(sGameModes, "") )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) == -1 )
			return false;
	}

	GetConVarString(g_hCvarModesOff, sGameModes, sizeof(sGameModes));
	if( strcmp(sGameModes, "") )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) != -1 )
			return false;
	}

	return true;
}

public OnGamemode(const String:output[], caller, activator, Float:delay)
{
	if( strcmp(output, "OnCoop") == 0 )
		g_iCurrentMode = 1;
	else if( strcmp(output, "OnSurvival") == 0 )
		g_iCurrentMode = 2;
	else if( strcmp(output, "OnVersus") == 0 )
		g_iCurrentMode = 4;
	else if( strcmp(output, "OnScavenge") == 0 )
		g_iCurrentMode = 8;
}



// ====================================================================================================
//					EVENTS
// ====================================================================================================
public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	ResetPlugin(false);
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
		CreateTimer(g_iMap == 1 ? 5.0 : 1.0, tmrStart);
	g_iRoundStart = 1;
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
		CreateTimer(g_iMap == 1 ? 5.0 : 1.0, tmrStart);
	g_iPlayerSpawn = 1;
}

public Action:tmrStart(Handle:timer)
{
	g_iMap = 0;
	ResetPlugin();
	LoadColas();

	if( g_iCvarSafe == 1 )
	{
		new iClients[MAXPLAYERS+1], count;

		for( new i = 1; i <= MaxClients; i++ )
			if( IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) )
				iClients[count++] = i;

		new client = GetRandomInt(0, count-1);
		client = iClients[client];

		if( client )
		{
			decl Float:vPos[3], Float:vAng[3];
			GetClientAbsOrigin(client, vPos);
			GetClientAbsAngles(client, vAng);
			vPos[2] += 25.0;
			CreateCola(vPos, vAng);
		}
	}
	else if( g_iCvarSafe == 2 )
	{
		new iClients[MAXPLAYERS+1], count;

		for( new i = 1; i <= MaxClients; i++ )
			if( IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) )
				iClients[count++] = i;

		new client = GetRandomInt(0, count-1);
		client = iClients[client];

		if( client )
		{
			new entity = GivePlayerItem(client, "weapon_gnome");
			if( entity != -1 )
				EquipPlayerWeapon(client, entity);
		}
	}
}

public Event_ItemPickup(Handle:event, const String:name[], bool:dontBroadcast)
{
	if( g_iCvarHeal )
	{
		decl String:sTemp[16];
		GetEventString(event, "item", sTemp, sizeof(sTemp));
		if( strcmp(sTemp, "gnome") == 0 )
		{
			new client = GetClientOfUserId(GetEventInt(event, "userid"));
			g_iCola[client] = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

			if( g_hTimerHeal == INVALID_HANDLE )
				CreateTimer(0.1, tmrHeal, _, TIMER_REPEAT);
		}
	}
}

public Action:tmrHeal(Handle:timer)
{
	new entity, bool:healed;

	if( g_iCvarHeal )
	{
		for( new i = 1; i <= MaxClients; i++ )
		{
			entity = g_iCola[i];
			if( entity )
			{
				if( IsClientInGame(i) && IsPlayerAlive(i) && entity == GetEntPropEnt(i, Prop_Send, "m_hActiveWeapon") )
				{
					HealClient(i);
					healed = true;
				}
				else
					g_iCola[i] = 0;
			}
		}
	}

	if( healed == false )
	{
		g_hTimerHeal = INVALID_HANDLE;
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

HealClient(client)
{
	new iHealth = GetClientHealth(client);
	if( iHealth >= 100 )
		return;

	new Float:fGameTime = GetGameTime();
	new Float:fHealthTime = GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
	new Float:fHealth = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	fHealth -= (fGameTime - fHealthTime) * g_fCvarDecayRate;

	if( g_iCvarTemp == -1 || (g_iCvarTemp != 0 && GetRandomInt(1, 100) >= g_iCvarTemp) )
	{
		if( fHealth < 0.0 )
			fHealth = 0.0;

		new Float:fBuff = (0.1 * g_fCvarRate);

		if( fHealth + iHealth + fBuff > 100 )
			SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 100.1 - float(iHealth));
		else
			SetEntPropFloat(client, Prop_Send, "m_healthBuffer", fHealth + fBuff);
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", fGameTime);
	}
	else
	{
		if( fGameTime - g_fHealTime[client] > 1.0 )
		{
			g_fHealTime[client] = fGameTime;

			new iBuff = RoundToFloor(g_fCvarRate);
			iHealth += iBuff;
			if( iHealth >= 100 )
			{
				iHealth = 100;
				SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
				SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", fGameTime);
			}
			else if( iHealth + fHealth >= 100 )
			{
				SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 100.1 - iHealth);
				SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", fGameTime);
			}

			SetEntityHealth(client, iHealth);
		}
	}
}



// ====================================================================================================
//					LOAD COLAS
// ====================================================================================================
LoadColas()
{
	if( g_bLoaded || g_iCvarRandom == 0 ) return;
	g_bLoaded = true;

	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_SPAWNS);
	if( !FileExists(sPath) )
		return;

	// Load config
	new Handle:hFile = CreateKeyValues("gnome");
	if( !FileToKeyValues(hFile, sPath) )
	{
		CloseHandle(hFile);
		return;
	}

	// Check for current map in the config
	decl String:sMap[64];
	GetCurrentMap(sMap, 64);

	if( !KvJumpToKey(hFile, sMap) )
	{
		CloseHandle(hFile);
		return;
	}

	// Retrieve how many colas to display
	new iCount = KvGetNum(hFile, "num", 0);
	if( iCount == 0 )
	{
		CloseHandle(hFile);
		return;
	}

	// Spawn only a select few colas?
	new iIndexes[MAX_COLAS+1];
	if( iCount > MAX_COLAS )
		iCount = MAX_COLAS;


	// Spawn saved colas or create random
	new iRandom = g_iCvarRandom;
	if( iRandom == -1 || iRandom > iCount)
		iRandom = iCount;
	if( iRandom != -1 )
	{
		for( new i = 1; i <= iCount; i++ )
			iIndexes[i] = i;

		SortIntegers(iIndexes, iCount+1, Sort_Random);
		iCount = iRandom;
	}

	// Get the cola origins and spawn
	decl String:sTemp[10], Float:vPos[3], Float:vAng[3];
	new index;
	for( new i = 1; i <= iCount; i++ )
	{
		if( iRandom != -1 ) index = iIndexes[i];
		else index = i;

		IntToString(index, sTemp, sizeof(sTemp));

		if( KvJumpToKey(hFile, sTemp) )
		{
			KvGetVector(hFile, "angle", vAng);
			KvGetVector(hFile, "origin", vPos);

			if( vPos[0] == 0.0 && vPos[0] == 0.0 && vPos[0] == 0.0 ) // Should never happen.
				LogError("Error: 0,0,0 origin. Iteration=%d. Index=%d. Random=%d. Count=%d.", i, index, iRandom, iCount);
			else
				CreateCola(vPos, vAng, index);
			KvGoBack(hFile);
		}
	}

	CloseHandle(hFile);
}



// ====================================================================================================
//					CREATE COLA
// ====================================================================================================
CreateCola(const Float:vOrigin[3], const Float:vAngles[3], index = 0)
{
	if( g_iColaCount >= MAX_COLAS )
		return;

	new iColaIndex = -1;
	for( new i = 0; i < MAX_COLAS; i++ )
	{
		if( g_iColas[i][0] == 0 )
		{
			iColaIndex = i;
			break;
		}
	}

	if( iColaIndex == -1 )
		return;

	new entity = CreateEntityByName("prop_physics");
	if( entity == -1 )
		ThrowError("Failed to create cola model.");

	g_iColas[iColaIndex][0] = EntIndexToEntRef(entity);
	g_iColas[iColaIndex][1] = index;
	SetEntityModel(entity, MODEL_COLA);

	DispatchSpawn(entity);
	TeleportEntity(entity, vOrigin, vAngles, NULL_VECTOR);

	if( g_iCvarGlow )
	{
		SetEntProp(entity, Prop_Send, "m_nGlowRange", g_iCvarGlow);
		SetEntProp(entity, Prop_Send, "m_iGlowType", 1);
		SetEntProp(entity, Prop_Send, "m_glowColorOverride", g_iCvarGlowCol);
		AcceptEntityInput(entity, "StartGlowing");
	}

	g_iColaCount++;
}



// ====================================================================================================
//					COMMANDS
// ====================================================================================================
//					sm_cola
// ====================================================================================================
public Action:CmdColaTemp(client, args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Cola] Commands may only be used in-game on a dedicated server..");
		return Plugin_Handled;
	}
	else if( g_iColaCount >= MAX_COLAS )
	{
		PrintToChat(client, "%sError: Cannot add anymore colas. Used: (\x05%d/%d\x01).", CHAT_TAG, g_iColaCount, MAX_COLAS);
		return Plugin_Handled;
	}

	new Float:vPos[3], Float:vAng[3];
	if( !SetTeleportEndPoint(client, vPos, vAng) )
	{
		PrintToChat(client, "%sCannot place cola, please try again.", CHAT_TAG);
		return Plugin_Handled;
	}

	CreateCola(vPos, vAng);
	return Plugin_Handled;
}

// ====================================================================================================
//					sm_colasave
// ====================================================================================================
public Action:CmdColaSave(client, args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Cola] Commands may only be used in-game on a dedicated server..");
		return Plugin_Handled;
	}
	else if( g_iColaCount >= MAX_COLAS )
	{
		PrintToChat(client, "%sError: Cannot add anymore colas. Used: (\x05%d/%d\x01).", CHAT_TAG, g_iColaCount, MAX_COLAS);
		return Plugin_Handled;
	}

	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_SPAWNS);
	if( !FileExists(sPath) )
	{
		new Handle:hCfg = OpenFile(sPath, "w");
		WriteFileLine(hCfg, "");
		CloseHandle(hCfg);
	}

	// Load config
	new Handle:hFile = CreateKeyValues("gnome");
	if( !FileToKeyValues(hFile, sPath) )
	{
		PrintToChat(client, "%sError: Cannot read the cola config, assuming empty file. (\x05%s\x01).", CHAT_TAG, sPath);
	}

	// Check for current map in the config
	decl String:sMap[64];
	GetCurrentMap(sMap, 64);
	if( !KvJumpToKey(hFile, sMap, true) )
	{
		PrintToChat(client, "%sError: Failed to add map to cola spawn config.", CHAT_TAG);
		CloseHandle(hFile);
		return Plugin_Handled;
	}

	// Retrieve how many colas are saved
	new iCount = KvGetNum(hFile, "num", 0);
	if( iCount >= MAX_COLAS )
	{
		PrintToChat(client, "%sError: Cannot add anymore colas. Used: (\x05%d/%d\x01).", CHAT_TAG, iCount, MAX_COLAS);
		CloseHandle(hFile);
		return Plugin_Handled;
	}

	// Save count
	iCount++;
	KvSetNum(hFile, "num", iCount);

	decl String:sTemp[10];

	IntToString(iCount, sTemp, sizeof(sTemp));
	if( KvJumpToKey(hFile, sTemp, true) )
	{
		new Float:vPos[3], Float:vAng[3];
		// Set player position as cola spawn location
		if( !SetTeleportEndPoint(client, vPos, vAng) )
		{
			PrintToChat(client, "%sCannot place cola, please try again.", CHAT_TAG);
			CloseHandle(hFile);
			return Plugin_Handled;
		}

		// Save angle / origin
		KvSetVector(hFile, "angle", vAng);
		KvSetVector(hFile, "origin", vPos);

		CreateCola(vPos, vAng, iCount);

		// Save cfg
		KvRewind(hFile);
		KeyValuesToFile(hFile, sPath);

		PrintToChat(client, "%s(\x05%d/%d\x01) - Saved at pos:[\x05%f %f %f\x01] ang:[\x05%f %f %f\x01]", CHAT_TAG, iCount, MAX_COLAS, vPos[0], vPos[1], vPos[2], vAng[0], vAng[1], vAng[2]);
	}
	else
		PrintToChat(client, "%s(\x05%d/%d\x01) - Failed to save Cola.", CHAT_TAG, iCount, MAX_COLAS);

	CloseHandle(hFile);
	return Plugin_Handled;
}

// ====================================================================================================
//					sm_coladel
// ====================================================================================================
public Action:CmdColaDelete(client, args)
{
	if( !g_bCvarAllow )
	{
		ReplyToCommand(client, "[SM] Plugin turned off.");
		return Plugin_Handled;
	}

	if( !client )
	{
		ReplyToCommand(client, "[Cola] Commands may only be used in-game on a dedicated server..");
		return Plugin_Handled;
	}

	new entity = GetClientAimTarget(client, false);
	if( entity == -1 ) return Plugin_Handled;
	entity = EntIndexToEntRef(entity);

	new cfgindex, index = -1;
	for( new i = 0; i < MAX_COLAS; i++ )
	{
		if( g_iColas[i][0] == entity )
		{
			index = i;
			break;
		}
	}

	if( index == -1 )
		return Plugin_Handled;

	cfgindex = g_iColas[index][1];
	if( cfgindex == 0 )
	{
		RemoveCola(index);
		return Plugin_Handled;
	}

	for( new i = 0; i < MAX_COLAS; i++ )
	{
		if( g_iColas[i][1] > cfgindex )
			g_iColas[i][1]--;
	}

	g_iColaCount--;

	// Load config
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_SPAWNS);
	if( !FileExists(sPath) )
	{
		PrintToChat(client, "%sError: Cannot find the cola config (\x05%s\x01).", CHAT_TAG, CONFIG_SPAWNS);
		return Plugin_Handled;
	}

	new Handle:hFile = CreateKeyValues("colas");
	if( !FileToKeyValues(hFile, sPath) )
	{
		PrintToChat(client, "%sError: Cannot load the cola config (\x05%s\x01).", CHAT_TAG, sPath);
		CloseHandle(hFile);
		return Plugin_Handled;
	}

	// Check for current map in the config
	decl String:sMap[64];
	GetCurrentMap(sMap, 64);

	if( !KvJumpToKey(hFile, sMap) )
	{
		PrintToChat(client, "%sError: Current map not in the cola config.", CHAT_TAG);
		CloseHandle(hFile);
		return Plugin_Handled;
	}

	// Retrieve how many colas
	new iCount = KvGetNum(hFile, "num", 0);
	if( iCount == 0 )
	{
		CloseHandle(hFile);
		return Plugin_Handled;
	}

	new bool:bMove;
	decl String:sTemp[16];

	// Move the other entries down
	for( new i = cfgindex; i <= iCount; i++ )
	{
		IntToString(i, sTemp, sizeof(sTemp));
		if( KvJumpToKey(hFile, sTemp) )
		{
			if( !bMove )
			{
				bMove = true;
				KvDeleteThis(hFile);
				RemoveCola(index);
			}
			else
			{
				IntToString(i-1, sTemp, sizeof(sTemp));
				KvSetSectionName(hFile, sTemp);
			}
		}

		KvRewind(hFile);
		KvJumpToKey(hFile, sMap);
	}

	if( bMove )
	{
		iCount--;
		KvSetNum(hFile, "num", iCount);

		// Save to file
		KvRewind(hFile);
		KeyValuesToFile(hFile, sPath);

		PrintToChat(client, "%s(\x05%d/%d\x01) - Cola removed from config.", CHAT_TAG, iCount, MAX_COLAS);
	}
	else
		PrintToChat(client, "%s(\x05%d/%d\x01) - Failed to remove Cola from config.", CHAT_TAG, iCount, MAX_COLAS);

	CloseHandle(hFile);
	return Plugin_Handled;
}

// ====================================================================================================
//					sm_colawipe
// ====================================================================================================
public Action:CmdColaWipe(client, args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Cola] Commands may only be used in-game on a dedicated server..");
		return Plugin_Handled;
	}

	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_SPAWNS);
	if( !FileExists(sPath) )
	{
		PrintToChat(client, "%sError: Cannot find the cola config (\x05%s\x01).", CHAT_TAG, sPath);
		return Plugin_Handled;
	}

	// Load config
	new Handle:hFile = CreateKeyValues("colas");
	if( !FileToKeyValues(hFile, sPath) )
	{
		PrintToChat(client, "%sError: Cannot load the cola config (\x05%s\x01).", CHAT_TAG, sPath);
		CloseHandle(hFile);
		return Plugin_Handled;
	}

	// Check for current map in the config
	decl String:sMap[64];
	GetCurrentMap(sMap, 64);

	if( !KvJumpToKey(hFile, sMap, false) )
	{
		PrintToChat(client, "%sError: Current map not in the cola config.", CHAT_TAG);
		CloseHandle(hFile);
		return Plugin_Handled;
	}

	KvDeleteThis(hFile);
	ResetPlugin();

	// Save to file
	KvRewind(hFile);
	KeyValuesToFile(hFile, sPath);
	CloseHandle(hFile);

	PrintToChat(client, "%s(0/%d) - All colas removed from config, add with \x05sm_colasave\x01.", CHAT_TAG, MAX_COLAS);
	return Plugin_Handled;
}

// ====================================================================================================
//					sm_colaglow
// ====================================================================================================
public Action:CmdColaGlow(client, args)
{
	static bool:glow;
	glow = !glow;
	PrintToChat(client, "%sGlow has been turned %s", CHAT_TAG, glow ? "on" : "off");

	VendorGlow(glow);
	return Plugin_Handled;
}

VendorGlow(glow)
{
	new ent;

	for( new i = 0; i < MAX_COLAS; i++ )
	{
		ent = g_iColas[i][0];
		if( IsValidEntRef(ent) )
		{
			SetEntProp(ent, Prop_Send, "m_iGlowType", 3);
			SetEntProp(ent, Prop_Send, "m_glowColorOverride", 65535);
			SetEntProp(ent, Prop_Send, "m_nGlowRange", glow ? 0 : 50);
			ChangeEdictState(ent, FindSendPropOffs("prop_dynamic", "m_nGlowRange"));
		}
	}
}

// ====================================================================================================
//					sm_colalist
// ====================================================================================================
public Action:CmdColaList(client, args)
{
	decl Float:vPos[3];
	new count;
	for( new i = 0; i < MAX_COLAS; i++ )
	{
		if( IsValidEntRef(g_iColas[i][0]) )
		{
			count++;
			GetEntPropVector(g_iColas[i][0], Prop_Data, "m_vecOrigin", vPos);
			PrintToChat(client, "%s%d) %f %f %f", CHAT_TAG, i+1, vPos[0], vPos[1], vPos[2]);
		}
	}
	PrintToChat(client, "%sTotal: %d.", CHAT_TAG, count);
	return Plugin_Handled;
}

// ====================================================================================================
//					sm_colatele
// ====================================================================================================
public Action:CmdColaTele(client, args)
{
	if( args == 1 )
	{
		decl String:arg[16];
		GetCmdArg(1, arg, 16);
		new index = StringToInt(arg) - 1;
		if( index > -1 && index < MAX_COLAS && IsValidEntRef(g_iColas[index][0]) )
		{
			decl Float:vPos[3];
			GetEntPropVector(g_iColas[index][0], Prop_Data, "m_vecOrigin", vPos);
			vPos[2] += 20.0;
			TeleportEntity(client, vPos, NULL_VECTOR, NULL_VECTOR);
			PrintToChat(client, "%sTeleported to %d.", CHAT_TAG, index + 1);
			return Plugin_Handled;
		}

		PrintToChat(client, "%sCould not find index for teleportation.", CHAT_TAG);
	}
	else
		PrintToChat(client, "%sUsage: sm_colatele <index 1-%d>.", CHAT_TAG, MAX_COLAS);
	return Plugin_Handled;
}

// ====================================================================================================
//					MENU ANGLE
// ====================================================================================================
public Action:CmdColaAng(client, args)
{
	ShowMenuAng(client);
	return Plugin_Handled;
}

ShowMenuAng(client)
{
	CreateMenus();
	DisplayMenu(g_hMenuAng, client, MENU_TIME_FOREVER);
}

public AngMenuHandler(Handle:menu, MenuAction:action, client, index)
{
	if( action == MenuAction_Select )
	{
		if( index == 6 )
			SaveData(client);
		else
			SetAngle(client, index);
		ShowMenuAng(client);
	}
}

SetAngle(client, index)
{
	new aim = GetClientAimTarget(client, false);
	if( aim != -1 )
	{
		new Float:vAng[3], entity;
		aim = EntIndexToEntRef(aim);

		for( new i = 0; i < MAX_COLAS; i++ )
		{
			entity = g_iColas[i][0];

			if( entity == aim  )
			{
				GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);

				if( index == 0 ) vAng[0] += 5.0;
				else if( index == 1 ) vAng[1] += 5.0;
				else if( index == 2 ) vAng[2] += 5.0;
				else if( index == 3 ) vAng[0] -= 5.0;
				else if( index == 4 ) vAng[1] -= 5.0;
				else if( index == 5 ) vAng[2] -= 5.0;

				TeleportEntity(entity, NULL_VECTOR, vAng, NULL_VECTOR);

				PrintToChat(client, "%sNew angles: %f %f %f", CHAT_TAG, vAng[0], vAng[1], vAng[2]);
				break;
			}
		}
	}
}

// ====================================================================================================
//					MENU ORIGIN
// ====================================================================================================
public Action:CmdColaPos(client, args)
{
	ShowMenuPos(client);
	return Plugin_Handled;
}

ShowMenuPos(client)
{
	CreateMenus();
	DisplayMenu(g_hMenuPos, client, MENU_TIME_FOREVER);
}

public PosMenuHandler(Handle:menu, MenuAction:action, client, index)
{
	if( action == MenuAction_Select )
	{
		if( index == 6 )
			SaveData(client);
		else
			SetOrigin(client, index);
		ShowMenuPos(client);
	}
}

SetOrigin(client, index)
{
	new aim = GetClientAimTarget(client, false);
	if( aim != -1 )
	{
		new Float:vPos[3], entity;
		aim = EntIndexToEntRef(aim);

		for( new i = 0; i < MAX_COLAS; i++ )
		{
			entity = g_iColas[i][0];

			if( entity == aim  )
			{
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);

				if( index == 0 ) vPos[0] += 0.5;
				else if( index == 1 ) vPos[1] += 0.5;
				else if( index == 2 ) vPos[2] += 0.5;
				else if( index == 3 ) vPos[0] -= 0.5;
				else if( index == 4 ) vPos[1] -= 0.5;
				else if( index == 5 ) vPos[2] -= 0.5;

				TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);

				PrintToChat(client, "%sNew origin: %f %f %f", CHAT_TAG, vPos[0], vPos[1], vPos[2]);
				break;
			}
		}
	}
}

SaveData(client)
{
	new entity, index;
	new aim = GetClientAimTarget(client, false);
	if( aim == -1 )
		return;

	aim = EntIndexToEntRef(aim);

	for( new i = 0; i < MAX_COLAS; i++ )
	{
		entity = g_iColas[i][0];

		if( entity == aim  )
		{
			index = g_iColas[i][1];
			break;
		}
	}

	if( index == 0 )
		return;

	// Load config
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_SPAWNS);
	if( !FileExists(sPath) )
	{
		PrintToChat(client, "%sError: Cannot find the cola config (\x05%s\x01).", CHAT_TAG, CONFIG_SPAWNS);
		return;
	}

	new Handle:hFile = CreateKeyValues("colas");
	if( !FileToKeyValues(hFile, sPath) )
	{
		PrintToChat(client, "%sError: Cannot load the cola config (\x05%s\x01).", CHAT_TAG, sPath);
		CloseHandle(hFile);
		return;
	}

	// Check for current map in the config
	decl String:sMap[64];
	GetCurrentMap(sMap, 64);

	if( !KvJumpToKey(hFile, sMap) )
	{
		PrintToChat(client, "%sError: Current map not in the cola config.", CHAT_TAG);
		CloseHandle(hFile);
		return;
	}

	decl Float:vAng[3], Float:vPos[3], String:sTemp[32];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);
	GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);

	IntToString(index, sTemp, sizeof(sTemp));
	if( KvJumpToKey(hFile, sTemp) )
	{
		KvSetVector(hFile, "angle", vAng);
		KvSetVector(hFile, "origin", vPos);

		// Save cfg
		KvRewind(hFile);
		KeyValuesToFile(hFile, sPath);

		PrintToChat(client, "%sSaved origin and angles to the data config", CHAT_TAG);
	}
}

CreateMenus()
{
	if( g_hMenuAng == INVALID_HANDLE )
	{
		g_hMenuAng = CreateMenu(AngMenuHandler);
		AddMenuItem(g_hMenuAng, "", "X + 5.0");
		AddMenuItem(g_hMenuAng, "", "Y + 5.0");
		AddMenuItem(g_hMenuAng, "", "Z + 5.0");
		AddMenuItem(g_hMenuAng, "", "X - 5.0");
		AddMenuItem(g_hMenuAng, "", "Y - 5.0");
		AddMenuItem(g_hMenuAng, "", "Z - 5.0");
		AddMenuItem(g_hMenuAng, "", "SAVE");
		SetMenuTitle(g_hMenuAng, "Set Angle");
		SetMenuExitButton(g_hMenuAng, true);
	}

	if( g_hMenuPos == INVALID_HANDLE )
	{
		g_hMenuPos = CreateMenu(PosMenuHandler);
		AddMenuItem(g_hMenuPos, "", "X + 0.5");
		AddMenuItem(g_hMenuPos, "", "Y + 0.5");
		AddMenuItem(g_hMenuPos, "", "Z + 0.5");
		AddMenuItem(g_hMenuPos, "", "X - 0.5");
		AddMenuItem(g_hMenuPos, "", "Y - 0.5");
		AddMenuItem(g_hMenuPos, "", "Z - 0.5");
		AddMenuItem(g_hMenuPos, "", "SAVE");
		SetMenuTitle(g_hMenuPos, "Set Position");
		SetMenuExitButton(g_hMenuPos, true);
	}
}



// ====================================================================================================
//					STUFF
// ====================================================================================================
bool:IsValidEntRef(entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}

ResetPlugin(bool:all = true)
{
	g_bLoaded = false;
	g_iColaCount = 0;
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;

	for( new i = 1; i <= MAXPLAYERS; i++ )
		g_fHealTime[i] = 0.0;

	if( all )
		for( new i = 0; i < MAX_COLAS; i++ )
			RemoveCola(i);
}

RemoveCola(index)
{
	new entity = g_iColas[index][0];
	g_iColas[index][0] = 0;

	if( IsValidEntRef(entity) )
		AcceptEntityInput(entity, "kill");
}



// ====================================================================================================
//					POSITION
// ====================================================================================================
SetTeleportEndPoint(client, Float:vPos[3], Float:vAng[3])
{
	GetClientEyePosition(client, vPos);
	GetClientEyeAngles(client, vAng);

	new Handle:trace = TR_TraceRayFilterEx(vPos, vAng, MASK_SHOT, RayType_Infinite, _TraceFilter);

	if(TR_DidHit(trace))
	{
		decl Float:vNorm[3];
		TR_GetEndPosition(vPos, trace);
		TR_GetPlaneNormal(trace, vNorm);
		new Float:angle = vAng[1];
		GetVectorAngles(vNorm, vAng);

		vPos[2] += 5.0;

		if( vNorm[2] == 1.0 )
		{
			vAng[0] = 0.0;
			vAng[1] += angle;
		}
		else
		{
			vAng[0] = 0.0;
			vAng[1] += angle - 90.0;
		}
	}
	else
	{
		CloseHandle(trace);
		return false;
	}
	CloseHandle(trace);
	return true;
}

public bool:_TraceFilter(entity, contentsMask)
{
	return entity > MaxClients || !entity;
}