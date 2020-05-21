#define RUST_CULTIST 0
#define FLESH_CULTIST 1
#define ASH_CULTIST 2


/proc/isecultist(mob/living/M)
	return M && M.mind && M.mind.has_antag_datum(/datum/antagonist/ecult)

/datum/antagonist/ecult
	name = "Eldritch Cultist"
	roundend_category = "eldritch cultist"
	antagpanel_category = "Eldritch Cult"
	antag_moodlet = /datum/mood_event/ecult
	job_rank = ROLE_ECULTIST
	var/ignore_implant = FALSE
	var/give_equipment = TRUE
	var/datum/team/ecult/ecult_team
	var/list/researched_knowledge = list()
	var/total_sacrifices = 0

/datum/antagonist/ecult/get_team()
	return ecult_team

/datum/antagonist/ecult/admin_add(datum/mind/new_owner,mob/admin)
	give_equipment = FALSE
	new_owner.add_antag_datum(src)
	message_admins("[key_name_admin(admin)] has cult'ed [key_name_admin(new_owner)].")
	log_admin("[key_name(admin)] has cult'ed [key_name(new_owner)].")


/datum/antagonist/ecult/create_team(datum/team/cult/new_team)
	if(!new_team)
		ecult_team = new /datum/team/ecult
		return
	if(!istype(new_team))
		stack_trace("Wrong team type passed to [type] initialization.")
	ecult_team = new_team

/datum/antagonist/ecult/proc/add_objectives()
	objectives |= ecult_team.objectives

/datum/antagonist/ecult/greet()
	owner.current.playsound_local(get_turf(owner.current), 'sound/ambience/antag/ecult_op.ogg', 100, FALSE, pressure_affected = FALSE)//subject to change
	to_chat(owner, "<span class='boldannounce'>You are the Eldritch Cultist!</span>")
	to_chat(owner, "<B>The old ones gave you these tasks to fulfill:</B>")
	owner.announce_objectives()
	to_chat(owner, "Your magic uses souls of the dead. You are very weak at first,")
	to_chat(owner, "but the more souls you reap the more powerful you become.")
	to_chat(owner, "You can choose a specific old one you can worship:")
	to_chat(owner, "Rust - decay and destruction, passive destructive abilities")
	to_chat(owner, "Flesh - life and necrosis, allows you to ressurect the dead and summon deadly beasts.")
	to_chat(owner, "Ash - shadows and secrets, stealth and movement based abilties.")
	to_chat(owner,"<B>Remember your power comes with souls!</B>")

/datum/antagonist/ecult/on_gain()
	var/mob/living/current = owner.current
	if(ishuman(current))
		forge_primary_objectives()
		gain_knowledge(/datum/eldritch_knowledge/spell/basic)
		gain_knowledge(/datum/eldritch_knowledge/living_heart)
	current.log_message("has been converted to the cult of the forgotten ones!", LOG_ATTACK, color="#960000")
	if(!GLOB.reality_smash_track)
		new /datum/reality_smash_tracker()
		GLOB.reality_smash_track.Generate(1)
	GLOB.reality_smash_track.AddMind(owner)
	START_PROCESSING(SSprocessing,src)
	if(give_equipment)
		equip_cultist()
	. = ..()

/datum/antagonist/ecult/on_removal()

	for(var/X in researched_knowledge)
		var/datum/eldritch_knowledge/EK = X
		EK.on_lose(owner.current)

	if(!silent)
		owner.current.visible_message("<span class='deconversion_message'>[owner.current] looks like [owner.current.p_theyve()] just reverted to [owner.current.p_their()] old faith!</span>", null, null, null, owner.current)
		to_chat(owner.current, "<span class='userdanger'>Your mind begins to flare as the otherwordly knowledge escapes your grasp!</span>")
		owner.current.log_message("has renounced the cult of the old ones!", LOG_ATTACK, color="#960000")
	GLOB.reality_smash_track.RemoveMind(owner)
	STOP_PROCESSING(SSprocessing,src)

	. = ..()

/datum/antagonist/ecult/proc/equip_cultist()
	var/mob/living/carbon/H = owner.current
	if(!istype(H))
		return
	. += ecult_give_item(/obj/item/forbidden_book, H)
	. += ecult_give_item(/obj/item/living_heart, H)

/datum/antagonist/ecult/proc/ecult_give_item(obj/item/item_path, mob/living/carbon/human/H)
	var/list/slots = list(
		"backpack" = ITEM_SLOT_BACKPACK,
		"left pocket" = ITEM_SLOT_LPOCKET,
		"right pocket" = ITEM_SLOT_RPOCKET
	)

	var/T = new item_path(H)
	var/item_name = initial(item_path.name)
	var/where = H.equip_in_one_of_slots(T, slots)
	if(!where)
		to_chat(H, "<span class='userdanger'>Unfortunately, you weren't able to get a [item_name]. This is very bad and you should adminhelp immediately (press F1).</span>")
		return 0
	else
		to_chat(H, "<span class='danger'>You have a [item_name] in your [where].</span>")
		if(where == "backpack")
			SEND_SIGNAL(H.back, COMSIG_TRY_STORAGE_SHOW, H)
		return TRUE


/datum/antagonist/ecult/process()

	for(var/X in researched_knowledge)
		var/datum/eldritch_knowledge/EK = X
		EK.on_life(owner.current)

	for(var/X in objectives)
		if(!istype(X,/datum/objective/stalk))
			continue
		var/datum/objective/stalk/S = X
		if(S.target in view(7,src) && S.target && S.target.current.stat == CONSCIOUS)
			S.timer -= 10
	return

/datum/antagonist/ecult/proc/forge_primary_objectives()
	var/list/assasination = list()
	var/list/protection = list()
	for(var/i = 0 , i < 2 , i++)
		var/pck = pick("assasinate","stalk","protect")
		switch(pck)
			if("assasinate")
				var/datum/objective/assassinate/A = new
				A.owner = owner
				A.find_target(owner,protection)
				assasination += A.target
				objectives += A
			if("stalk")
				var/datum/objective/stalk/S = new
				S.owner = owner
				S.find_target()
				S.update_explanation_text()
				objectives += S
			if("protect")
				var/datum/objective/protect/P = new
				P.owner = owner
				P.find_target(owner,assasination)
				protection += P.target
				objectives += P

	var/datum/objective/sacrifice_ecult/SE = new
	SE.update_explanation_text()
	objectives += SE

	return

/datum/antagonist/ecult/apply_innate_effects(mob/living/mob_override)
	. = ..()
	var/mob/living/current = owner.current
	if(mob_override)
		current = mob_override
	handle_clown_mutation(current, mob_override ? null : "Knowledge described in the book allowed you to overcome your clownish nature, allowing you to wield weaponry.")
	current.faction |= "ecult"

/datum/antagonist/ecult/remove_innate_effects(mob/living/mob_override)
	. = ..()
	var/mob/living/current = owner.current
	if(mob_override)
		current = mob_override
	handle_clown_mutation(current, removing = FALSE)
	current.faction -= "ecult"


/datum/team/ecult
	name = "Eldritch Cult"

////////////////
// Knowledge //
////////////////

/datum/antagonist/ecult/proc/gain_knowledge(datum/eldritch_knowledge/EK)
	if(has_knowledge(EK))
		return FALSE
	var/datum/eldritch_knowledge/initialized_knowledge = new EK
	researched_knowledge |= initialized_knowledge
	initialized_knowledge.on_gain(owner.current)
	return TRUE

/datum/antagonist/ecult/proc/get_researchable_knowledge()
	var/list/researchable_knowledge = list()
	var/list/banned_knowledge = list()
	for(var/X in researched_knowledge)
		var/datum/eldritch_knowledge/EK = X
		researchable_knowledge |= EK.next_knowledge
		banned_knowledge |= EK.banned_knowledge
		banned_knowledge |= EK.type
	researchable_knowledge -= banned_knowledge
	return researchable_knowledge

/datum/antagonist/ecult/proc/has_knowledge(datum/eldritch_knowledge/EK)
	for(var/X in researched_knowledge)
		var/datum/eldritch_knowledge/EK1 = X
		if(initial(EK.name) == EK1.name)
			return TRUE
	return FALSE

/datum/antagonist/ecult/proc/get_knowledge(datum/eldritch_knowledge/EK)
	for(var/X in researched_knowledge)
		var/datum/eldritch_knowledge/EK1 = X
		if(istype(EK1,EK))
			return EK1

/datum/antagonist/ecult/proc/get_all_knowledge()
	return researched_knowledge

////////////////
// Objectives //
////////////////

/datum/objective/stalk
	name = "spendtime"
	var/timer = 1800 //5 minutes

/datum/objective/stalk/update_explanation_text()
	if(timer == initial(timer))//just so admins can mess with it
		timer += pick(-600, 600)
	if(target && target.current)
		explanation_text = "Stalk [target.name] for at least [DisplayTimeText(timer)] while they're alive."
	else
		explanation_text = "Free Objective"

/datum/objective/stalk/check_completion()
	return timer <= 0 || explanation_text == "Free Objective"

/datum/objective/sacrifice_ecult
	name = "sacrifice"

/datum/objective/sacrifice_ecult/update_explanation_text()
	. = ..()
	target_amount = rand(4,6)
	explanation_text = "Sacrifice at least [target_amount] people."

/datum/objective/sacrifice_ecult/check_completion()
	var/list/datum/mind/owners = get_owners()
	var/sacrificed = 0
	for(var/datum/mind/M in owners)
		if(!M)
			continue
		var/datum/antagonist/ecult/cultie = M.has_antag_datum(/datum/antagonist/ecult)
		if(!cultie)
			continue
		sacrificed += cultie.total_sacrifices
	return sacrificed >= target_amount
