if not nebAbilityUtil then
  nebAbilityUtil = {};
  
  --Thanks to C0bra5 for helping
  --Backup an ability
  function nebAbilityUtil.backupAbility(abilityToBackup)
	local ret = {};
	for k,v in pairs(abilityToBackup) do
	  if type(v) == "table" then
		-- including weapon causes an infinite loop
		if v ~= "weapon" then
 		  ret[k] = nebAbilityUtil.copyTable(v, 1);
		end
	  else
		ret[k] = v;
	  end
	end
	return ret;
  end
	
  --Copy a table
  function nebAbilityUtil.copyTable(table, count)
	local ret = {};
	for k,v in pairs(table) do
	  if type(v) == "table" then
		if count > 10 then
		  sb.logInfo("%s", k);
		  ret[k] = nebAbilityUtil.copyTable(v, count + 1);
	    end
	  else
	 	ret[k] = v;
	  end
	end
    return ret;
  end
	
  --Restore an ability DEPRECATED
  --function nebAbilityUtil.restoreAbility(backup, weapon)
  --  local ret = nebAbilityUtil.copyTable(backup, 1)
  --  ret.weapon = weapon;
  --  return ret;
  --end
end