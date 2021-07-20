#include <sdktools>
#include <sdkhooks>

#include "bettertools/serverside_inferno.sp"

#pragma semicolon 1
#pragma newdecls required

#define PREFIX "[BetterTools] "
#define SOUND_BARRICADE_COLLECT "weapons/melee/hammer/board_damage-light3.wav"

#define MATERIAL_WOOD 1
#define MAX_ENTITIES 2048

#define EXT_NONE 0 // Can't be extinguished
#define EXT_REMOVE 1 // Extinguish by removing
#define EXT_EXT 2 // Extinguish by extinguishing..

#define ACT_REACH_OUT_IDLE 7
#define ACT_REACH_OUT_WALK 10

float shouldExtinguishTime[MAX_ENTITIES+1] = {-1.0, ...};	// When the entity should be extinguished, should we not lose progress
float lastSprayTime[MAX_ENTITIES+1] = {-1.0, ...};			// Next time we should spray this entity so as to not lose progress

float shouldIgniteTime[MAX_ENTITIES+1] = {-1.0, ...};
float lastHeatTime[MAX_ENTITIES+1] = {-1.0, ...};

float nextThink[MAXPLAYERS+1] = {-1.0, ...};

ConVar cvExtinguishTime;
ConVar cvIgniteTime;
ConVar cvExtEverywhere;

ConVar cvTweakExt, cvTweakZippo, cvTweakBarr;
ConVar cvIgniteHumans, cvIgniteZombies, cvIgniteProps;
ConVar cvFF, cvBarricadeHealth, cvBarricadeMdl;
ConVar cvZippoRange, cvExtinguishRange;

bool qolPluginExists;
bool lateloaded;

public Plugin myinfo = 
{
	name        = "Better Tools",
	author      = "Dysphie",
	description = "Extended functionality for tools",
	version     = "0.1.3",
	url         = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	lateloaded = late;
}

public void OnPluginStart()
{
	if (GetFeatureStatus(FeatureType_Capability, "SDKHook_OnEntitySpawned") == FeatureStatus_Unavailable)
		SetFailState("Requires SourceMod 1.11 or higher");

	AddNormalSoundHook(OnSound);
	AddTempEntHook("EffectDispatch", OnEffectDispatch);

	cvFF = FindConVar("mp_friendlyfire");
	cvBarricadeHealth = FindConVar("sv_barricade_health");
	cvBarricadeMdl = FindConVar("cl_barricade_board_model"); // ..why is this cl_

	cvIgniteTime = CreateConVar("sm_zippo_use_time", "2.0", 
		"Seconds it takes the zippo to ignite an entity");

	cvExtinguishTime = CreateConVar("sm_extinguisher_use_time", "2.0",
		"Seconds it takes the fire extinguisher to extinguish an entity");

	cvExtEverywhere = FindConVar("sv_extinguisher_always_fire");

	cvTweakExt = CreateConVar("sm_extinguisher_tweaks", "1", 
		"Toggles extended fire extinguisher functionality");

	cvTweakZippo = CreateConVar("sm_zippo_tweaks", "1", 
		"Toggles extended zippo functionality");

	cvTweakBarr = CreateConVar("sm_barricade_tweaks", "1", 
		"Toggles extended barricade tool functionality");

	cvIgniteZombies = CreateConVar("sm_zippo_ignites_zombies", "1", 
		"Zippo can ignite zombies");

	cvIgniteHumans = CreateConVar("sm_zippo_ignites_humans", "0", 
		"Zippo can ignite other players (abides by friendly fire and infection rules)");

	cvIgniteProps = CreateConVar("sm_zippo_ignites_props", "1", 
		"Zippo can ignite breakable wooden props and explosives");

	cvZippoRange = CreateConVar("sm_zippo_range", "75.0");
	cvExtinguishRange = CreateConVar("sm_extinguisher_range", "200.0");

	if (lateloaded)
	{
		int e = -1;
		while ((e = FindEntityByClassname(e, "prop_physics_multiplayer")) != -1)
			if (IsEntityBarricade(e))
				OnBarricadeSpawned(e);
	}

	AutoExecConfig();
}

public void OnAllPluginsLoaded()
{
	qolPluginExists = LibraryExists("qol");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "qol"))
		qolPluginExists = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "qol"))
		qolPluginExists = false;
}

public void OnConfigsExecuted()
{
	cvExtEverywhere.AddChangeHook(OnExtEverywhereConVarChanged);
	EnsureExtinguisherWorksEverywhere();
}

public void OnMapStart()
{
	PrecacheSound(SOUND_BARRICADE_COLLECT);
}

public void OnExtEverywhereConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	EnsureExtinguisherWorksEverywhere(true);
}

void EnsureExtinguisherWorksEverywhere(bool notify = false)
{
	if (cvTweakExt.BoolValue && !cvExtEverywhere.BoolValue)
	{
		cvExtEverywhere.BoolValue = true;

		if (notify)
			PrintToServer(PREFIX ... "Forcing \"sv_extinguisher_always_fire\" to 1 \
				while extinguisher tweaks are enabled");
	}
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int _weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	float curTime = GetTickedTime();
	if (curTime < nextThink[client])
		return;

	nextThink[client] = curTime + 0.1;

	int curWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (curWeapon != -1)
	{
		char classname[19];
		GetEntityClassname(curWeapon, classname, sizeof(classname));

		if (cvTweakExt.BoolValue && StrEqual(classname, "tool_extinguisher"))
			FireExtinguisherThink(client, curWeapon);
		else if (cvTweakZippo.BoolValue && StrEqual(classname, "item_zippo"))
			ZippoThink(client, curWeapon);
	}
}

void FireExtinguisherThink(int client, int extinguisher)
{
	if (!GetEntProp(extinguisher, Prop_Data, "m_bHoseFiring"))
		return;

	float hullAng[3], hullStart[3], hullEnd[3];
	GetClientEyeAngles(client, hullAng);
	GetClientEyePosition(client, hullStart);

	ForwardVector(hullStart, hullAng, cvExtinguishRange.FloatValue, hullEnd); // endPos is eyes + range

	TR_EnumerateEntitiesHull(hullStart, hullEnd, 
		{-20.0, -20.0, -20.0}, {20.0, 20.0, 20.0}, MASK_ALL, OnEntitySprayed);
}

public bool TraceFilter_IgnoreOne(int entity, int contentsMask, int ignore)
{
	return entity != ignore;
}

void ZippoThink(int client, int zippo)
{
	// Is zippo lit
	if (!GetEntProp(zippo, Prop_Send, "_ignited"))
		return;

	// Is arm reaching out
	int act = GetEntProp(zippo, Prop_Send, "m_nSequence");
	if (act != ACT_REACH_OUT_WALK && act != ACT_REACH_OUT_IDLE)
		return;

	float eyePos[3], eyeAng[3], endPos[3];
	GetClientEyePosition(client, eyePos);
	GetClientEyeAngles(client, eyeAng);

	ForwardVector(eyePos, eyeAng, cvZippoRange.FloatValue, endPos); 

	TR_TraceRayFilter(eyePos, endPos, MASK_ALL, RayType_EndPoint, TraceFilter_IgnoreOne, client);

	int target = TR_GetEntityIndex();
	if (IsValidEdict(target))
		OnEntityZippoed(target, TR_GetSurfaceProps());
}

void OnEntityZippoed(int entity, int surface)
{
	// Ignore if the entity is already on fire or it's being extinguished
	if (!CheckCanIgnite(entity, surface))
	{
		shouldIgniteTime[entity] == -1.0;
		return;
	}

	float curTime = GetTickedTime();

	// Ignore entities that are being extinguished
	if (curTime - lastSprayTime[entity] < 0.5)
	{
		shouldIgniteTime[entity] == -1.0;
		return;
	}

	// If we haven't ignited this entity in a while (or ever), update the goal time
	if (curTime - lastHeatTime[entity] > 0.5)
		shouldIgniteTime[entity] = curTime + cvIgniteTime.FloatValue;

	lastHeatTime[entity] = curTime;

	if (curTime >= shouldIgniteTime[entity])
	{
		shouldIgniteTime[entity] == -1.0;
		Ignite(entity);
	}

	return;
}


bool OnEntitySprayed(int entity)
{
	if (!IsValidEdict(entity))
		return true;

	int extMethod = CheckCanExtinguish(entity);
	if (!extMethod)
	{
		shouldExtinguishTime[entity] == -1.0;
		return true;
	}

	float curTime = GetTickedTime();

	// If we haven't sprayed this entity in a while (or ever), update the goal time
	if (curTime - lastSprayTime[entity] > 0.5)
		shouldExtinguishTime[entity] = curTime + cvExtinguishTime.FloatValue;

	lastSprayTime[entity] = curTime;

	if (curTime >= shouldExtinguishTime[entity])
	{
		if (extMethod == EXT_REMOVE)
			RemoveEntity(entity);
		else
			Extinguish(entity);

		shouldExtinguishTime[entity] == -1.0;
	}

	return true;
}


int CheckCanExtinguish(int entity)
{
	if (!(GetEntityFlags(entity) & FL_ONFIRE))
	{
		char classname[20];
		GetEntityClassname(entity, classname, sizeof(classname));
		if (StrEqual(classname, "molotov_projectile"))
			return EXT_REMOVE;

		return EXT_NONE;
	}

	if (IsEntityPlayer(entity) || IsEntityZombie(entity))
		return EXT_EXT;
	
	char classname[20];
	GetEntityClassname(entity, classname, sizeof(classname));
	if (StrEqual(classname, "func_breakable") || StrContains(classname, "prop_physics") == 0)
		return EXT_EXT;

	return EXT_NONE;
}

bool IsFlammableSurface(int idx)
{
	// Indexes foor wood/paper, taken from nmrih/scripts/surfaceproperties.txt
	return 15 <= idx < 22 || idx == 28 || idx == 49 || idx == 73 || idx == 74;
}

bool CheckCanIgnite(int entity, int surface)
{
	if (GetEntityFlags(entity) & FL_ONFIRE)
		return false;

	if (IsEntityPlayer(entity))
		return cvIgniteHumans.BoolValue && (cvFF.BoolValue || IsClientInfected(entity));

	if (IsEntityZombie(entity))
		return cvIgniteZombies.BoolValue;

	if (cvIgniteProps.BoolValue)
	{
		char classname[20];
		GetEntityClassname(entity, classname, sizeof(classname));
		if (StrEqual(classname, "func_breakable"))
		{
			int health = GetEntProp(entity, Prop_Data, "m_iHealth");
			int material = GetEntProp(entity, Prop_Data, "m_Material");
			return health > 0 && material == MATERIAL_WOOD;
		}

		if (IsExplosiveEntity(entity))
			return true;

		// Else only ignite wooden surfaces
		return IsFlammableSurface(surface);
	}

	return false;
}

bool IsExplosiveEntity(int entity)
{
	return HasEntProp(entity, Prop_Data, "m_explodeRadius") && 
		GetEntPropFloat(entity, Prop_Data, "m_explodeRadius") > 0.0;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (IsValidEdict(entity))
	{
		shouldExtinguishTime[entity] = -1.0;
		lastSprayTime[entity] = -1.0;

		shouldIgniteTime[entity] = -1.0;
		lastHeatTime[entity] = -1.0;
	}
}

void Extinguish(int entity)
{
	char classname[32];
	GetEntityClassname(entity, classname, sizeof(classname));

	if (StrEqual(classname, "molotov_projectile"))
	{
		RemoveEntity(entity);
	}
	else if (GetEntityFlags(entity) & FL_ONFIRE)
	{
		// ExtinguishEntity(entity);
		int effect = GetEntPropEnt(entity, Prop_Send, "m_hEffectEntity");
		if (IsValidEdict(effect))
		{
			char effectname[20];
			GetEntityClassname(effect, effectname, sizeof(effectname));

			if (StrEqual(effectname, "entityflame"))
				RemoveEntity(effect);
		}
	}
}

void Ignite(int entity)
{
	SetVariantFloat(30.0);
	AcceptEntityInput(entity, "ignitelifetime");
}

public Action OnBarricadeDamaged(int barricade, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	if (qolPluginExists || !cvTweakBarr.BoolValue)
		return Plugin_Continue;

	if (GetEntityHealth(barricade) < cvBarricadeHealth.IntValue)
		return Plugin_Continue;

	if (IsEntityPlayer(attacker) && IsValidEdict(inflictor) && IsBarricadeTool(inflictor))
	{
		int spawner = CreateEntityByName("random_spawner");
		if (spawner == -1)
			return Plugin_Continue;
			
		DispatchKeyValue(spawner, "ammobox_board", "100");
		DispatchKeyValue(spawner, "spawnflags", "6");    // "don't spawn on map start" and "toss me about"
		DispatchKeyValue(spawner, "ammo_fill_pct_max", "100");
		DispatchKeyValue(spawner, "ammo_fill_pct_min", "100");
		
		if (!DispatchSpawn(spawner))
			return Plugin_Continue;
	
		float origin[3], angles[3];
		GetEntPropVector(barricade, Prop_Data, "m_vecAbsOrigin", origin);
		GetEntPropVector(barricade, Prop_Data, "m_angAbsRotation", angles);

		TeleportEntity(spawner, origin, angles);
		AcceptEntityInput(spawner, "InputSpawn");

		RemoveEntity(spawner);
		RemoveEntity(barricade);

		EmitSoundToAll(SOUND_BARRICADE_COLLECT, barricade);
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

bool IsEntityPlayer(int entity)
{
	return 0 < entity <= MaxClients;
}

bool IsBarricadeTool(int entity)
{
	return HasEntProp(entity, Prop_Data, "m_bBarricading");
}

int GetEntityHealth(int entity)
{
	return GetEntProp(entity, Prop_Data, "m_iHealth");
}

void ForwardVector(const float pos[3], const float ang[3], float distance, float dest[3])
{
	float dir[3];
	GetAngleVectors(ang, dir, NULL_VECTOR, NULL_VECTOR);
	dest = pos;
	dest[0] += dir[0] * distance;
	dest[1] += dir[1] * distance;
	dest[2] += dir[2] * distance;
}

bool IsEntityZombie(int entity)
{
	return HasEntProp(entity, Prop_Send, "_headSplit");
}

bool IsClientInfected(int client)
{
	return GetEntPropFloat(client, Prop_Send, "m_flInfectionTime") != -1.0;
}

public void OnEntitySpawned(int entity, const char[] classname)
{
	if (StrEqual(classname, "prop_physics_multiplayer") && IsEntityBarricade(entity))
		OnBarricadeSpawned(entity);
}

bool IsEntityBarricade(int entity)
{
	static char model[PLATFORM_MAX_PATH];
	GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));

	static char barricadeModel[PLATFORM_MAX_PATH];
	cvBarricadeMdl.GetString(barricadeModel, sizeof(barricadeModel));

	return StrEqual(model, barricadeModel);
}

public void OnBarricadeSpawned(int barricade)
{
	SDKHook(barricade, SDKHook_OnTakeDamage, OnBarricadeDamaged);
}
