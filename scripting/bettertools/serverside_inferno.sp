/* 
 * Moves molotov particle effects to the server side and links
 * them to the molotov projectile so they can be extinguished 
 */

int lastDetonated = INVALID_ENT_REFERENCE;
int lastDetonatedTick = -1;

public Action OnEffectDispatch(const char[] te_name, const int[] players, int numClients, float delay)
{
	int effectID = TE_ReadNum("m_iEffectName");

	char buffer[64];
	GetEffectName(effectID, buffer, sizeof(buffer));

	if (StrEqual(buffer, "ParticleEffect"))
	{
		int hitbox = TE_ReadNum("m_nHitBox");
		GetParticleEffectName(hitbox, buffer, sizeof(buffer));

		if (StrEqual(buffer, "nmrih_molotov_explosion") && 
			IsValidEntity(lastDetonated) && lastDetonatedTick == GetGameTickCount())
		{
			// Move the effect to the server side so we can remove it at will
			float pos[3];
			pos[0] = TE_ReadFloat("m_vOrigin[0]");
			pos[1] = TE_ReadFloat("m_vOrigin[1]");
			pos[2] = TE_ReadFloat("m_vOrigin[2]");

			CreateMolotovInferno(lastDetonated, pos);
			return Plugin_Handled;
		}	
	}

	return Plugin_Continue;
}

public Action OnSound(int clients[MAXPLAYERS], int& numClients, char sample[PLATFORM_MAX_PATH], int& entity, int& channel, float& volume, int& level, int& pitch, int& flags, char soundEntry[PLATFORM_MAX_PATH], int& seed)
{
	if (IsValidEdict(entity) && StrContains(sample, "exp_molotov/molotov_explode") != -1)
	{
		char classname[20];
		GetEntityClassname(entity, classname, sizeof(classname));

		if (StrEqual(classname, "molotov_projectile"))
			OnMolotovDetonated(entity);
	}
}

void OnMolotovDetonated(int molotov)
{
	lastDetonated = EntIndexToEntRef(molotov);
	lastDetonatedTick = GetGameTickCount();
}

int CreateMolotovInferno(int molotov, float pos[3])
{
	int particle = CreateEntityByName("info_particle_system");
	DispatchKeyValue(particle, "targetname", "molotov_inferno");
	DispatchKeyValue(particle, "effect_name", "nmrih_molotov_explosion");
	DispatchSpawn(particle);
	ActivateEntity(particle);

	TeleportEntity(particle, pos);
	AcceptEntityInput(particle, "Start");

	SetVariantString("!activator");
	AcceptEntityInput(particle, "SetParent", molotov);

	return particle;
}

int GetParticleEffectName(int index, char[] buffer, int maxlen)
{
	static int table = INVALID_STRING_TABLE;
	
	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("ParticleEffectNames");
	
	return ReadStringTable(table, index, buffer, maxlen);
}

int GetEffectName(int index, char[] buffer, int maxlen)
{
	static int table = INVALID_STRING_TABLE;
	
	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("EffectDispatch");
	
	ReadStringTable(table, index, buffer, maxlen);
}