#include <sourcemod>
#include <sdktools_functions>
#include <colors>

public Plugin:myinfo =
{
	name = "Public Match Plugin",
	author = "Aphex",
	description = "Public Match server Plugin",
	version = "0.0.0.1",
	url = "http://www.sourcemod.net/"
};

enum MATCH_STATUS
{
	WAITING,
	STARTING,
	LIVE_ON_RESTART,
	LIVE,
	STOPING,
	ENDED
};

new String:g_chat_command_prefix[32] = "#.#";
new MATCH_STATUS:g_match_status = MATCH_STATUS:WAITING;


new Handle:g_maplist;
enum PAUSE_STATE
{
	NOT_PAUSED,
	PAUSED,
	UNPAUSING
};

new PAUSE_STATE:g_paused = NOT_PAUSED;

#define TEAM_SPECTATORS 1
#define TEAM_SECURITY 2
#define TEAM_INSURGENTS 3
new bool:g_team_r[4];
new g_player_cnt;


new String:g_hostname[64];

new Handle:g_cv_pmp_cmd_prefix;
new Handle:g_cv_pmp_welcome;
new Handle:g_cv_pmp_hostname_tail_status;
new Handle:g_cv_pmp_hostname;
new Handle:g_cv_pmp_disable_kill;




public OnPluginStart(){
	g_maplist = CreateArray(32);
	
	g_cv_pmp_cmd_prefix = CreateConVar("sm_pmp_cmd_prefix",				g_chat_command_prefix,	"Chat command prefix");
	g_cv_pmp_welcome = CreateConVar("sm_pmp_welcome",				"1",			"Enable player welcome message");
	g_cv_pmp_hostname_tail_status = CreateConVar("sm_pmp_hostname_tail_status",	"1",			"Enables displaying server status at hostname tail");
	g_cv_pmp_hostname = CreateConVar("sm_pmp_hostname",				"Your hostname | ",	"Dynamic hostname");
	g_cv_pmp_disable_kill = CreateConVar("sm_pmp_disable_kill",			"1",			"Disable 'kill' cmd for players");


	HookConVarChange(g_cv_pmp_cmd_prefix, OnCVChatCommandPrefixChange);

	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_Say);


	HookEvent("game_start", GameEvents_GameStart);
	HookEvent("game_end", GameEvents_GameEnd);
	HookEvent("round_start", GameEvents_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_team", GameEvents_player_team);//, EventHookMode_PostNoCopy);

	if(GetConVarBool(g_cv_pmp_disable_kill))
		SetCommandFlags("kill", GetCommandFlags("kill")|FCVAR_CHEAT);
}

public OnPluginEnd(){
	if(GetConVarBool(g_cv_pmp_disable_kill))
		SetCommandFlags("kill", GetCommandFlags("kill") & ~(FCVAR_CHEAT));
}


public OnCVChatCommandPrefixChange(Handle:convar, const String:oldValue[], const String:newValue[]){
	strcopy(g_chat_command_prefix, sizeof(g_chat_command_prefix), newValue);
	SetConVarString(convar, g_chat_command_prefix);
}

public OnMapStart(){
	change_status(MATCH_STATUS:WAITING);
}

public OnConfigsExecuted(){
	//new Handle:cv_hostname = FindConVar("hostname");
	//GetConVarString(cv_hostname, g_hostname, sizeof(g_hostname));
	GetConVarString(g_cv_pmp_hostname, g_hostname, sizeof(g_hostname));

	new maplist_serial = -1;
	ReadMapList(g_maplist, maplist_serial, "default", MAPLIST_FLAG_CLEARARRAY);

	change_status(MATCH_STATUS:WAITING);
}

public OnClientPutInServer(client){
	//if(!IsFakeClient(client))
	g_player_cnt++;
	player_welcome(client);
}

public OnClientDisconnect(client){
	//if(!IsFakeClient(client))
	g_player_cnt--;
	new ti = GetClientTeam(client);
	if(g_player_cnt < 2){
		if(g_player_cnt < 1){
			map_advance(); //Change map/reload server configs after last player disconnected
		}
		if(g_match_status == MATCH_STATUS:LIVE){ // Stop match if only one player left
			change_status(MATCH_STATUS:STOPING);
			return;
		}
	}
	if(g_match_status == MATCH_STATUS:LIVE){
		if(g_paused == PAUSE_STATE:NOT_PAUSED){
			if(ti != TEAM_SPECTATORS){
	 			PrintToChatAll("Auto pausing game due player disconnect");
				pause_game();
			}
		}
	}
}

public Action:map_advance(){
	if(g_player_cnt > 0)
		return;
	new String:map[64];
	new Handle:nextmap = FindConVar("nextlevel");
	if(nextmap != INVALID_HANDLE){
		GetConVarString(nextmap, map, sizeof(map));
		if(!StrEqual(map, "") && IsMapValid(map)){
			ServerCommand("changelevel \"%s\"", map);
		}else{
			GetCurrentMap(map, sizeof(map));
		}
	}else{
		GetCurrentMap(map, sizeof(map));
	}
	ServerCommand("changelevel \"%s\"", map);
	ServerExecute();
}


public pause_game(){
	g_paused = PAUSE_STATE:PAUSED;
	InsertServerCommand("pause");
	ServerExecute();
}



public Action:Command_Say(client, args){
	if (client <= 0 || client > MaxClients)
		return Plugin_Continue;	
	new String:message[512];
	GetCmdArgString(message, sizeof(message));
	StripQuotes(message);
	TrimString(message);
	
	new String:m_args[6][512];
	new m_args_cnt;
	m_args_cnt = ExplodeString(message, " ", m_args, sizeof(m_args), sizeof(m_args[]), true);  //TODO:replace by BreakString
	new ti = GetClientTeam(client);
	if(m_args_cnt >= 2){
		if(ti != TEAM_SPECTATORS && strcmp(m_args[0], g_chat_command_prefix) == 0){
			if(StrEqual(m_args[1], "help"))			cmd_fn_help(client, m_args);
			else if(StrEqual(m_args[1], "h"))		cmd_fn_help(client, m_args);
			//else if(StrEqual(m_args[1], "start"))		cmd_fn_start(client, m_args);
			else if(StrEqual(m_args[1], "r"))		cmd_fn_ready(client, m_args);
			else if(StrEqual(m_args[1], "ready"))		cmd_fn_ready(client, m_args);
			else if(StrEqual(m_args[1], "nr"))		cmd_fn_notready(client, m_args);
			else if(StrEqual(m_args[1], "notready"))	cmd_fn_notready(client, m_args);
			else if(StrEqual(m_args[1], "stop"))		cmd_fn_stop(client, m_args);
			else if(StrEqual(m_args[1], "cm"))		cmd_fn_changemap(client, m_args);
			else if(StrEqual(m_args[1], "map"))		cmd_fn_changemap(client, m_args);
			else if(StrEqual(m_args[1], "nm"))		cmd_fn_nextmap(client, m_args);
			else if(StrEqual(m_args[1], "nextmap"))		cmd_fn_nextmap(client, m_args);
			else if(StrEqual(m_args[1], "p"))		cmd_fn_pause(client, m_args);
			else if(StrEqual(m_args[1], "pause"))		cmd_fn_pause(client, m_args);
			else if(StrEqual(m_args[1], "rr"))		cmd_fn_restartround(client, m_args);
			else if(StrEqual(m_args[1], "restartround"))	cmd_fn_restartround(client, m_args);
			else if(StrEqual(m_args[1], "rg"))		cmd_fn_restartgame(client, m_args);
			else if(StrEqual(m_args[1], "restartgame"))	cmd_fn_restartgame(client, m_args);
			else if(StrEqual(m_args[1], "st"))		cmd_fn_switchteams(client, m_args);
			else if(StrEqual(m_args[1], "switchteams"))	cmd_fn_switchteams(client, m_args);
			else if(StrEqual(m_args[1], "sp"))		cmd_fn_showpassword(client, m_args);
			else if(StrEqual(m_args[1], "showpassword"))	cmd_fn_showpassword(client, m_args);
			else if(StrEqual(m_args[1], "status"))		cmd_fn_status(client, m_args);
			else if(StrEqual(m_args[1], "ks"))		cmd_fn_kickspectators(client, m_args);
			else if(StrEqual(m_args[1], "kickspectators"))	cmd_fn_kickspectators(client, m_args);
			else{
				PrintToChat(client, "Unknown command\nTry \"%s help\" for command list.", g_chat_command_prefix);
			}
			return Plugin_Handled;
		}
	}
	if(g_paused == PAUSE_STATE:PAUSED || g_paused == PAUSE_STATE:UNPAUSING){
		new String:cname[50];
		GetClientName(client, cname, sizeof(cname));
		if(ti == TEAM_SECURITY)
			CPrintToChatAll("{red}%s: {default}%s", cname, message);
		else if(ti == TEAM_INSURGENTS)
			CPrintToChatAll("{blue}%s: {default}%s", cname, message);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public change_status(MATCH_STATUS:status){
	if(status == g_match_status) return;
	g_match_status = status;
	if(status == MATCH_STATUS:WAITING)		on_match_waiting();
	else if(status == MATCH_STATUS:STARTING)	on_match_starting();
	else if(status == MATCH_STATUS:LIVE)		on_match_live();
	else if(status == MATCH_STATUS:STOPING)		on_match_stoping();
	else if(status == MATCH_STATUS:ENDED)		on_match_ended();
}

public change_concat_to_hostname(String:tail[]){
	if(!GetConVarBool(g_cv_pmp_hostname_tail_status))
		return;
	new String:n_hostname[64];
	strcopy(n_hostname, sizeof(n_hostname), g_hostname);
	StrCat(n_hostname, sizeof(n_hostname), tail);
	InsertServerCommand("hostname \"%s\"", n_hostname);
	ServerExecute();
}





public on_match_waiting(){
	InsertServerCommand("exec server.cfg");
        ServerExecute();

	new Handle:cv_password = FindConVar("sv_password");
	new String:password[32];
	GetConVarString(cv_password, password, sizeof(password));
	if(!StrEqual(password, "")){
		new String:buf[32];
		Format(buf, sizeof(buf), "Password: %s", password);
		change_concat_to_hostname(buf);
	}


	g_team_r[TEAM_SECURITY] = false;
        g_team_r[TEAM_INSURGENTS] = false;
	CPrintToChatAll("{green}Not ready");
	InsertServerCommand("mp_minteamplayers 50");
	InsertServerCommand("mp_joinwaittime 100000");
	ServerExecute();
}

public on_match_starting(){
	new String:passwd[5];
	new passwd_r = GetRandomInt(1000, 9999);
	IntToString(passwd_r, passwd, sizeof(passwd));

	InsertServerCommand("mp_minteamplayers 1");
	InsertServerCommand("mp_joinwaittime 1");
	InsertServerCommand("sv_password \"%s\"", passwd);
	ServerExecute();

        change_concat_to_hostname("Match in progress");


	CreateTimer(1.0, start_stage_1);
}

public on_match_live(){
	CPrintToChatAll("{green}%s","=>|GL|--!LIVE!--|HF|<=")
	g_team_r[TEAM_SECURITY] = false;
	g_team_r[TEAM_INSURGENTS] = false;
}

public on_match_stoping(){
	CPrintToChatAll("{green}%s","Stoping match")
	InsertServerCommand("mp_restartgame 1");
	ServerExecute();
	change_status(MATCH_STATUS:WAITING);
}

public on_match_ended(){
	
}



public cmd_fn_start(client, String:m_args[][]){
	if(g_match_status == MATCH_STATUS:WAITING){
		change_status(MATCH_STATUS:STARTING);
		return;
	}
	PrintToChat(client, "Game already started!");
}
public cmd_fn_stop(client, String:m_args[][]){
	if(g_match_status == MATCH_STATUS:LIVE){
		change_status(MATCH_STATUS:STOPING);
		return;
	}
	PrintToChat(client, "Game not running.");
}



public cmd_fn_changemap(client, String:m_args[][]){
	new String:s_map[32];
	strcopy(String:s_map, sizeof(s_map), m_args[2]);
	new map_cnt = GetArraySize(g_maplist);
	decl String:c_map[32];
	for (new i = 0; i < map_cnt; i++){
		GetArrayString(g_maplist, i, c_map, sizeof(c_map));
		if(StrEqual(c_map, s_map)){
			PrintToChatAll("Changing map to %s", s_map);
			InsertServerCommand("sm_nextmap \"%s\"", s_map);
                        InsertServerCommand("nextlevel \"%s\"", s_map);
			ServerExecute();
			InsertServerCommand("changelevel \"%s\"", s_map);
			ServerExecute();
			return;
		}
	}
	PrintToChat(client, "Map '%s' not found", s_map);

}
public cmd_fn_nextmap(client, String:m_args[][]){
	new String:s_map[32];
	strcopy(String:s_map, sizeof(s_map), m_args[2]);
	new map_cnt = GetArraySize(g_maplist);
	decl String:c_map[32];
	for (new i = 0; i < map_cnt; i++){
		GetArrayString(g_maplist, i, c_map, sizeof(c_map));
		if(StrEqual(c_map, s_map)){
			PrintToChatAll("Nextmap changed to %s", s_map);
			InsertServerCommand("sm_nextmap \"%s\"", s_map);
			InsertServerCommand("nextlevel \"%s\"", s_map);
			ServerExecute();
			return;
		}
	}
	PrintToChat(client, "Map '%s' not found", s_map);
}


public cmd_fn_restartround(client, String:m_args[][]){
	PrintToChatAll("Restarting round...");
	InsertServerCommand("mp_restartround 5");
	ServerExecute();
}

public cmd_fn_restartgame(client, String:m_args[][]){
	PrintToChatAll("Restarting game...");
	InsertServerCommand("mp_restartgame 5");
	ServerExecute();
}

public cmd_fn_switchteams(client, String:m_args[][]){
	PrintToChatAll("Teams will be switched");
	InsertServerCommand("mp_switchteams");
	InsertServerCommand("mp_restartround 1");
	ServerExecute();
}

public cmd_fn_pause(client, String:m_args[][]){
	if(g_paused == PAUSE_STATE:UNPAUSING)
		return;
	if(g_paused == PAUSE_STATE:NOT_PAUSED){
		if(g_match_status == MATCH_STATUS:LIVE){
			new String:cname[50];
			GetClientName(client, cname, sizeof(cname));
			CPrintToChatAll("%{green}%s {default}was requested game pause", cname);
			CPrintToChatAll(" {green}%s ready {default}when team will be ready", g_chat_command_prefix);
			pause_game();
		}else{
			PrintToChat(client, "Match not started yet.");
		}
	}else{
		if(StrEqual("f", m_args[2]) ||
		   StrEqual("force", m_args[2])){
			new String:cname[50];
			GetClientName(client, cname, sizeof(cname));
			CPrintToChatAll("{green}%s {default}was requested force unpause", cname);
			g_paused = PAUSE_STATE:UNPAUSING;
			CreateTimer(1.0, unpause_stage_1);
		}
	}
}

public cmd_fn_ready(client, String:m_args[][]){
	new ti = GetClientTeam(client);
	if(ti != TEAM_SECURITY && ti != TEAM_INSURGENTS)
		return;
	
	if(g_team_r[ti])team_set_notready(ti);
	else		team_set_ready(ti);
	check_teams_ready();
}

public cmd_fn_notready(client, String:m_args[][]){
	new ti = GetClientTeam(client);
	if(ti != TEAM_SECURITY && ti != TEAM_INSURGENTS)
		return;
	if(g_team_r[ti])
		team_set_notready(ti);
}



public team_set_notready(ti){
	new String:team[20];
        if(ti == TEAM_SECURITY)         team = "Security";
        else if(ti == TEAM_INSURGENTS)  team = "Insurgents"
	if(g_match_status == MATCH_STATUS:WAITING){ // Game start
		CPrintToChatAll("{green}%s {default}team {red}NOT {default}ready!", team);
	}else if(g_match_status == MATCH_STATUS:LIVE){
		if(g_paused == PAUSE_STATE:PAUSED){ // Unpause
			CPrintToChatAll("{green}%s {default}team {red}NOT {default}ready!", team);
		}
	}
	g_team_r[ti] = false;
}
public team_set_ready(ti){
	new String:team[20];
	if(ti == TEAM_SECURITY)         team = "Security";
	else if(ti == TEAM_INSURGENTS)  team = "Insurgents"
	if(g_match_status == MATCH_STATUS:WAITING){
		CPrintToChatAll("{green}%s {default}team {green}ready!", team);
	}else if(g_match_status == MATCH_STATUS:LIVE){
		if(g_paused == PAUSE_STATE:PAUSED){
			CPrintToChatAll("{green}%s {default}team {blue}ready!", team);
		}
	}
	g_team_r[ti] = true;
}
public check_teams_ready(){
	if(g_team_r[TEAM_SECURITY] && g_team_r[TEAM_INSURGENTS]){
		if(g_match_status == MATCH_STATUS:WAITING){
			if(g_player_cnt > 1){ // FIXME
				change_status(MATCH_STATUS:STARTING);
			}
		}else if(g_match_status == MATCH_STATUS:LIVE){
			if(g_paused == PAUSE_STATE:PAUSED){
				g_team_r[TEAM_SECURITY] = false;
				g_team_r[TEAM_INSURGENTS] = false;
				g_paused = PAUSE_STATE:UNPAUSING;
				CreateTimer(1.0, unpause_stage_1);
			}
		}
	}
}


public cmd_fn_kickspectators(client, String:m_args[][]){
	new maxplayers = GetMaxClients();
	for (new x = 1; x <= maxplayers ; x++){
		if(!IsClientInGame(x))
			continue;
		if(GetClientTeam(x) != TEAM_SPECTATORS)
			continue;
		KickClient(x, "Spectators was kicked");
	}
}



public cmd_fn_showpassword(client, String:m_args[][]){
	new Handle:cv_password = FindConVar("sv_password");
	new String:password[100];
	GetConVarString(cv_password, password, sizeof(password));

        CPrintToChat(client, "Password: {green}%s", password);
}


public cmd_fn_status(client, String:m_args[][]){
	print_status(client);
}

public print_status(client){
	new String:match_status[32];
	if(	g_match_status == MATCH_STATUS:WAITING)		match_status = "waiting the teams to get ready";
	else if(g_match_status == MATCH_STATUS:STARTING)	match_status = "starting match";
	else if(g_match_status == MATCH_STATUS:LIVE_ON_RESTART) match_status = "LOR";
	else if(g_match_status == MATCH_STATUS:LIVE)		match_status = "LIVE!";
	else if(g_match_status == MATCH_STATUS:STOPING)		match_status = "stoping";
	else if(g_match_status == MATCH_STATUS:ENDED)		match_status = "eneded";
	CPrintToChat(client, "Game state: {green}%s", match_status);
	if(g_team_r[TEAM_SECURITY])	CPrintToChat(client, "Security: {green}READY");
	else				CPrintToChat(client, "Security: {red}NOT {default}READY");
	if(g_team_r[TEAM_INSURGENTS])	CPrintToChat(client, "Insurgents: {green}READY");
	else				CPrintToChat(client, "Insurgents: {red}NOT {default}READY");
}

public cmd_fn_help(client, String:m_args[][]){
	CPrintToChat(client, "Usage: {green}%s COMMAND [arguments]", g_chat_command_prefix)
	CPrintToChat(client, "Arguments:");
	CPrintToChat(client, " {green}r         {default}     Marks team as ready/unready. After all teams are ready, executes config, generates server password and starts match");
	CPrintToChat(client, " {green}stop      {default}     Stop match");
	CPrintToChat(client, " {green}cm MAPNAME{default}     Changing map to MAPNAME");
	CPrintToChat(client, " {green}nm MAPNAME{default}     Changing nextmap to MAPNAME");
	CPrintToChat(client, " {green}p         {default}     Pause/unpause game");
	CPrintToChat(client, " {green}gr        {default}     Game restart");
	CPrintToChat(client, " {green}rr        {default}     Round restart");
	CPrintToChat(client, " {green}st        {default}     Switch teams");
	CPrintToChat(client, " {green}ks        {default}     Kick spectators");
	CPrintToChat(client, " {green}sp        {default}     Show password");
}

public player_welcome(client){
	if(!GetConVarBool(g_cv_pmp_welcome))
		return;
	CPrintToChat(client, "Welcome on match server");
	CPrintToChat(client, "Type {green}%s help {default} for command reference", g_chat_command_prefix);
	print_status(client);
}






public Action:GameEvents_GameStart(Handle:event, const String:name[], bool:dontBroadcast){
	return Plugin_Continue;
}
public Action:GameEvents_GameEnd(Handle:event, const String:name[], bool:dontBroadcast){
	change_status(MATCH_STATUS:ENDED);
	return Plugin_Continue;
}
public GameEvents_RoundStart(Handle:event, const String:name[], bool:dontBroadcast){
	if(g_match_status == MATCH_STATUS:LIVE_ON_RESTART){
		change_status(MATCH_STATUS:LIVE);
	}
}


public Action:GameEvents_player_team(Handle:event, const String:name[], bool:dontBroadcast){
	//new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new oldteam = GetEventInt(event, "oldteam"); 
	new team = GetEventInt(event, "team"); 

	//PrintToServer("EVENT:player_team | oldteam='%d', team='%d'", oldteam, team);
	if(oldteam && team != oldteam){
		if(g_match_status == MATCH_STATUS:LIVE){
			if(g_paused == PAUSE_STATE:NOT_PAUSED){
				PrintToChatAll("Auto pausing game due player team change");
				pause_game();
			}
		}
	}
	return Plugin_Continue;
}













public Action:start_stage_1(Handle:timer){
	CPrintToChatAll("{green}%s","=================");
	CPrintToChatAll("{green}%s","Game Ready!");
	CPrintToChatAll("{green}%s","=================");
	CPrintToChatAll("{green}%s","POV demo started? Status screenshot taken?");
	CPrintToChatAll("{green}%s","=================");
	CreateTimer(7.0, start_stage_2);
}

public Action:start_stage_2(Handle:timer){
	if(g_match_status != MATCH_STATUS:STARTING) return;
	CPrintToChatAll("{green}%s","-----> 5 <-----")
	CreateTimer(1.0, start_stage_3);
}

public Action:start_stage_3(Handle:timer){
	if(g_match_status != MATCH_STATUS:STARTING) return;
	CPrintToChatAll("{green}%s","----> 4 <----")
	CreateTimer(1.0, start_stage_4);
}

public Action:start_stage_4(Handle:timer){
	if(g_match_status != MATCH_STATUS:STARTING) return;
	CPrintToChatAll("{green}%s","---> 3 <---")
	CreateTimer(1.0, start_stage_5);
}

public Action:start_stage_5(Handle:timer){
	if(g_match_status != MATCH_STATUS:STARTING) return;
	CPrintToChatAll("{green}%s","--> 2 <--")
	CreateTimer(1.0, start_stage_6);
}

public Action:start_stage_6(Handle:timer){
	if(g_match_status != MATCH_STATUS:STARTING) return;
	CPrintToChatAll("{green}%s","-> 1 <-");	
	CreateTimer(1.0, start_stage_7);
}

public Action:start_stage_7(Handle:timer){
	if(g_match_status != MATCH_STATUS:STARTING) return;
	new Handle:cv_password = FindConVar("sv_password");
	new String:password[100];

	CPrintToChatAll("{green}%s","-> 1 <-");
	CPrintToChatAll("{green}%s","=>--!LIVE ON RESTART!<=");
	GetConVarString(cv_password, password, sizeof(password));
	CPrintToChatAll("Password was set to: {green}%s", password);
	InsertServerCommand("mp_restartgame 1");
	ServerExecute();
	change_status(MATCH_STATUS:LIVE_ON_RESTART);
}






public Action:unpause_stage_1(Handle:timer){
	CPrintToChatAll("{green}%s","-----> UNPAUSING <-----")
	CPrintToChatAll("{green}%s","-----> 5 <-----")
	CreateTimer(1.0, unpause_stage_2);
}
public Action:unpause_stage_2(Handle:timer){
	CPrintToChatAll("{green}%s","----> 4 <----")
	CreateTimer(1.0, unpause_stage_3);
}
public Action:unpause_stage_3(Handle:timer){
	CPrintToChatAll("{green}%s","---> 3 <---")
	CreateTimer(1.0, unpause_stage_4);
}
public Action:unpause_stage_4(Handle:timer){
	CPrintToChatAll("{green}%s","--> 2 <--")
	CreateTimer(1.0, unpause_stage_5);
}
public Action:unpause_stage_5(Handle:timer){
	CPrintToChatAll("{green}%s","-> 1 <-")
	CreateTimer(1.0, unpause_stage_6);
}
public Action:unpause_stage_6(Handle:timer){
	CPrintToChatAll("{green}%s","-> GO! <-")
	InsertServerCommand("unpause");
 	ServerExecute();
	g_paused = PAUSE_STATE:NOT_PAUSED;
}

