#include <sourcemod>



#if defined _matchplugin_ins_included
 #endinput
#endif
#define _matchplugin_ins_included




enum MPINS_MatchStatus{
	NONE,
	WAITING,
	STARTING,
	LIVE_ON_RESTART,
	LIVE,
	STOPING,
	ENDED
};

native MPINS_Native_RegCmd(String:cmd_alias[], String:cmd_fn_name[], Handle:cmd_plugin);


native MPINS_Native_ChatCmd(client, const String:message[]);
forward Action:MPINS_Native_OnChatCmd(client, const String:message[]);


native bool:MPINS_Native_SetMatchStatus(MPINS_MatchStatus:new_status);
forward MPINS_MatchStatus:MPINS_Native_GetMatchStatus();