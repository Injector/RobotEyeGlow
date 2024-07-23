#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>

#define PREFIX "\x074287F5[Robot Eye Glow]\x01"

public Plugin myinfo =
{
	name		= "Robot Eye Glow",
	author		= "Bloomstorm",
	version		= "1.0",
	url = "https://bloomstorm.ru/"
};

int g_iLeftEyeRef[MAXPLAYERS + 1];
int g_iRightEyeRef[MAXPLAYERS + 1];

bool g_bIsAlerted[MAXPLAYERS + 1];

bool g_bEnableEyeGlow[MAXPLAYERS + 1];
bool g_bIsRobot[MAXPLAYERS + 1];
bool g_bIsRobotChanged[MAXPLAYERS + 1];
float g_vecCustomEyeColor[MAXPLAYERS + 1][3];

// game/client/tf/c_tf_player.cpp - C_TFPlayer::UpdateMVMEyeGlowEffect line 10961
float g_vecGlowBlueColor[] = { 0.0, 240.0, 255.0 };
float g_vecGlowYellowColor[] = { 255.0, 180.0, 36.0 };

float g_vecGlowRedColor[] = { 255.0, 40.0, 0.0 };

ConVar g_CVar_enable_eyes_by_default;
ConVar g_CVar_alert_when_robot;
ConVar g_CVar_cant_turn_off;

public void OnPluginStart()
{
	RegConsoleCmd("sm_robot_eyes", Cmd_RobotEyes);
	RegAdminCmd("sm_yellow_robot_eyes", Cmd_YellowRobotEyes, ADMFLAG_GENERIC);
	
	CreateTimer(0.25, Timer_CheckRobotModel, _, TIMER_REPEAT);
	
	HookEvent("player_changeclass", Event_PlayerChangeClass);
	HookEvent("player_team", Event_PlayerTeam);
	
	g_CVar_alert_when_robot = CreateConVar("sm_robot_eyes_alert", "1", "Alert robot player that they can turn off eye glow", _, true, 0.0, true, 1.0);
	g_CVar_cant_turn_off = CreateConVar("sm_robot_eyes_cant_turn_off", "0", "Robot players can't turn off eye glow", _, true, 0.0, true, 1.0);
	g_CVar_enable_eyes_by_default = CreateConVar("sm_robot_eyes_by_default", "0", "Enable robot eye glow by default", _, true, 0.0, true, 1.0);
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			int iEnt = EntRefToEntIndex(g_iLeftEyeRef[i]);
			if (iEnt > 0)
				AcceptEntityInput(iEnt, "Kill");
			iEnt = EntRefToEntIndex(g_iRightEyeRef[i]);
			if (iEnt > 0)
				AcceptEntityInput(iEnt, "Kill");
		}
	}
}

public void OnClientPutInServer(int client)
{
	g_bEnableEyeGlow[client] = g_bIsRobot[client] = g_bIsRobotChanged[client] = g_bIsAlerted[client] = false;
	g_vecCustomEyeColor[client][0] = g_vecCustomEyeColor[client][1] = g_vecCustomEyeColor[client][2] = 0.0;
}

public void OnClientPostAdminCheck(int client)
{
	if (g_CVar_enable_eyes_by_default.IntValue >= 1)
	{
		g_bEnableEyeGlow[client] = true;
	}
}

// ----------------------------- Events -----------------------

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int iTeam = event.GetInt("team");
	
	//When player moves to another team, kill previous eyes to change eye color
	if (g_bIsRobot[client])
	{
		g_bIsRobotChanged[client] = false;
	}
	
	//We need to kill eyes when player moves to spectator
	if (iTeam == 1)
	{
		g_bIsRobot[client] = false;
		KillRobotEyes(client);
	}
}

public void Event_PlayerChangeClass(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (g_bIsRobot[client])
	{
		g_bIsRobotChanged[client] = false;
	}
}

// ----------------------------- Commands -----------------------

public Action Cmd_RobotEyes(int client, int args)
{
	if (g_CVar_cant_turn_off.IntValue >= 1 && g_bEnableEyeGlow[client])
	{
		ReplyToCommand(client, "%s You can't turn it off", PREFIX);
		return Plugin_Handled;
	}
	g_bEnableEyeGlow[client] = !g_bEnableEyeGlow[client];
	if (!g_bEnableEyeGlow[client])
	{
		KillRobotEyes(client);
	}
	g_bIsRobotChanged[client] = false;
	ReplyToCommand(client, "%s Robot eyes are %s", PREFIX, g_bEnableEyeGlow[client] ? "\x0700FF00activated" : "\x07FF0000deactivated");
	return Plugin_Handled;
}

public Action Cmd_YellowRobotEyes(int client, int args)
{
	bool bEnabled = g_vecCustomEyeColor[client][0] == g_vecGlowYellowColor[0] && g_vecCustomEyeColor[client][1] == g_vecGlowYellowColor[1] && g_vecCustomEyeColor[client][2] == g_vecGlowYellowColor[2];
	if (bEnabled)
	{
		g_vecCustomEyeColor[client][0] = g_vecCustomEyeColor[client][1] = g_vecCustomEyeColor[client][2] = 0.0;
		bEnabled = false;
	}
	else
	{
		g_vecCustomEyeColor[client] = g_vecGlowYellowColor;
		bEnabled = true;
	}
	g_bIsRobotChanged[client] = false;
	ReplyToCommand(client, "%s Hardcore robot eyes are %s", PREFIX, bEnabled ? "\x0700FF00activated" : "\x07FF0000deactivated");
	return Plugin_Handled;
}

// ----------------------------- Plugin logic -----------------------

void SpawnRobotEye(int client, float eyeColor[3], bool isLeft)
{
	int iOldEye = isLeft ? EntRefToEntIndex(g_iLeftEyeRef[client]) : EntRefToEntIndex(g_iRightEyeRef[client]);
	if (iOldEye > 0)
		AcceptEntityInput(iOldEye, "Kill");
	
	// Create dumb entity to control the RGB color
	char szGlowName[64];
	Format(szGlowName, sizeof(szGlowName), "rbeye_%i", client);
	int iColorEnt = CreateEntityByName("info_particle_system");
	DispatchKeyValue(iColorEnt, "targetname", szGlowName);
	DispatchKeyValueVector(iColorEnt, "origin", eyeColor);
	DispatchSpawn(iColorEnt);
	
	// Mark cpoint1 with our targetname rbeye_ to apply the RGB color
	int iGlow = CreateEntityByName("info_particle_system");
	DispatchKeyValue(iGlow, "effect_name", "bot_eye_glow");
	DispatchKeyValue(iGlow, "cpoint1", szGlowName);
	
	SetVariantString("!activator");
	AcceptEntityInput(iGlow, "SetParent", client);
	
	char szEye1[16], szEye2[16];
	szEye1 = "eye_1";
	szEye2 = "eye_2";
	
	if (IsGiantRobotModel(client))
	{
		szEye1 = "eye_boss_1";
		szEye2 = "eye_boss_2";
	}
	
	SetVariantString(isLeft ? szEye1 : szEye2);
	AcceptEntityInput(iGlow, "SetParentAttachment");
	
	DispatchSpawn(iGlow);
	ActivateEntity(iGlow);
	AcceptEntityInput(iGlow, "Start");
	
	// We successfully setted the color, we don't need this anymore
	SetVariantString("OnUser1 !self:kill::0.1:1");
	AcceptEntityInput(iColorEnt, "AddOutput");
	AcceptEntityInput(iColorEnt, "FireUser1");
	
	if (isLeft)
		g_iLeftEyeRef[client] = EntIndexToEntRef(iGlow);
	else
		g_iRightEyeRef[client] = EntIndexToEntRef(iGlow);
}

void SetRobotEyes(int client, bool useCustom, float eyeColor[3])
{
	int iTeam = GetClientTeam(client);
	float vecColor[3];
	
	if (useCustom)
	{
		vecColor = eyeColor;
	}
	else
	{
		switch (iTeam)
		{
			case 0:
				vecColor = { 255.0, 255.0, 255.0 };
			case 2:
				vecColor = g_vecGlowRedColor;
			case 3:
				vecColor = g_vecGlowBlueColor;
		}
	}
	KillRobotEyes(client);
	//Demomen and soldier bots have only one eye
	if (TF2_GetPlayerClass(client) != TFClass_DemoMan && TF2_GetPlayerClass(client) != TFClass_Soldier)
	{	
		SpawnRobotEye(client, vecColor, false);
	}
	SpawnRobotEye(client, vecColor, true);
}

void KillRobotEyes(int client)
{
	int iEnt = EntRefToEntIndex(g_iLeftEyeRef[client]);
	if (iEnt > 0)
		AcceptEntityInput(iEnt, "Kill");
	iEnt = EntRefToEntIndex(g_iRightEyeRef[client]);
	if (iEnt > 0)
		AcceptEntityInput(iEnt, "Kill");
}

public Action Timer_CheckRobotModel(Handle timer, int smth)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		if (GetClientTeam(i) == 1)
			continue;
		//Robots on BLU team already have eye glow on client-side
		if (GameRules_GetProp("m_bPlayingMannVsMachine") && TF2_GetClientTeam(i) != TFTeam_Red)
			continue;
		
		g_bIsRobot[i] = HasRobotModel(i);
		
		if (g_bIsRobot[i] && !g_bIsRobotChanged[i])
		{
			if (g_bEnableEyeGlow[i] || IsFakeClient(i))
			{
				bool bEnableCustomEyeColor = g_vecCustomEyeColor[i][0] != 0.0 || g_vecCustomEyeColor[i][1] != 0.0 || g_vecCustomEyeColor[i][2] != 0.0;
				if (IsFakeClient(i))
				{
					g_vecCustomEyeColor[i] = g_vecGlowYellowColor;
					bEnableCustomEyeColor = GetEntProp(i, Prop_Send, "m_nBotSkill") >= 2;
				}
				SetRobotEyes(i, bEnableCustomEyeColor, g_vecCustomEyeColor[i]);
				g_bIsRobotChanged[i] = true;
			}
			
			if (!g_bIsAlerted[i] && g_CVar_alert_when_robot.IntValue >= 1 && g_CVar_cant_turn_off.IntValue == 0)
			{
				PrintToChat(i, "%s \x07FFFF00Ты можешь включить или выключить глаза роботов! используй !robot_eyes", PREFIX);
				g_bIsAlerted[i] = true;
			}
		}
		else if (!g_bIsRobot[i] && g_bIsRobotChanged[i])
		{
			//Looks like the player changed his model back to human
			KillRobotEyes(i);
			g_bIsRobotChanged[i] = false;
		}
	}
	return Plugin_Continue;
}

stock bool HasRobotModel(int client)
{
	bool bHasModel;
	char szModel[256], szFormat[256], szClass[64];
	
	GetEntPropString(client, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
	TF2_GetNameOfClass(TF2_GetPlayerClass(client), szClass, sizeof(szClass));
	
	Format(szFormat, sizeof(szFormat), "models/bots/%s/bot_%s.mdl", szClass, szClass);
	
	bHasModel = StrEqual(szModel, szFormat);
	
	//Player possibly has giant model instead of regular one
	if (!bHasModel)
	{
		Format(szFormat, sizeof(szFormat), "models/bots/%s_boss/bot_%s_boss.mdl", szClass, szClass);
		bHasModel = StrEqual(szModel, szFormat);
	}
	
	return bHasModel;
}

stock bool IsGiantRobotModel(int client)
{
	char szModel[256], szFormat[256], szClass[64];
	
	GetEntPropString(client, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
	TF2_GetNameOfClass(TF2_GetPlayerClass(client), szClass, sizeof(szClass));
	
	Format(szFormat, sizeof(szFormat), "models/bots/%s_boss/bot_%s_boss.mdl", szClass, szClass);
	
	return StrEqual(szModel, szFormat);
}

stock void TF2_GetNameOfClass(TFClassType cl, char[] name, int maxlen)
{
	switch (cl)
	{
		case TFClass_Scout: Format(name, maxlen, "scout");
		case TFClass_Soldier: Format(name, maxlen, "soldier");
		case TFClass_Pyro: Format(name, maxlen, "pyro");
		case TFClass_DemoMan: Format(name, maxlen, "demo");
		case TFClass_Heavy: Format(name, maxlen, "heavy");
		case TFClass_Engineer: Format(name, maxlen, "engineer");
		case TFClass_Medic: Format(name, maxlen, "medic");
		case TFClass_Sniper: Format(name, maxlen, "sniper");
		case TFClass_Spy: Format(name, maxlen, "spy");
	}
}