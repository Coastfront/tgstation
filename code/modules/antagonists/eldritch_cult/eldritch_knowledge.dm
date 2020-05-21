
/datum/eldritch_knowledge
	///Name of the knowledge
	var/name = "Basic knowledge"
	///Description of the knowledge
	var/desc = "Basic knowledge of forbidden arts."
	///What shows up
	var/gain_text = ""
	///Cost of knowledge in souls
	var/cost = 0
	///Next knowledge in the research tree
	var/list/next_knowledge = list()
	///What knowledge this is incompatible with
	var/list/banned_knowledge = list()
	///Used with rituals, how many items this needs
	var/list/required_atoms = list()

	var/list/result_atoms = list()
	///What path is this on
	var/route = "Side"

/datum/eldritch_knowledge/New()
	. = ..()
	var/list/temp_list
	for(var/X in required_atoms)
		var/atom/A = X
		temp_list += list(typesof(A))
	required_atoms = temp_list

/datum/eldritch_knowledge/proc/on_gain(mob/user)
	to_chat(user, "<span class='warning'>[gain_text]</span>")
	return

/datum/eldritch_knowledge/proc/on_lose(mob/user)
	return

/datum/eldritch_knowledge/proc/on_life(mob/user)
	return

/datum/eldritch_knowledge/proc/recipe_snowflake_check(list/atoms,loc) //overwrite this if you want to have a snowflage check in the recipe.
	return TRUE

/datum/eldritch_knowledge/proc/on_finished_recipe(mob/living/user,list/atoms,loc)
	if(result_atoms.len == 0)
		return FALSE

	for(var/X in result_atoms)
		var/atom/A = X
		new A(loc)

	return TRUE

/datum/eldritch_knowledge/proc/cleanup_atoms(list/atoms)
	for(var/X in atoms)
		var/atom/A = X
		A.Destroy()
	return

/datum/eldritch_knowledge/proc/mansus_grasp_act(atom/target, mob/user, proximity_flag, click_parameters)
	return

/datum/eldritch_knowledge/proc/eldritch_blade_act(atom/target, mob/user, proximity_flag, click_parameters)
	return

//////////////
///Subtypes///
//////////////

/datum/eldritch_knowledge/spell
	var/obj/effect/proc_holder/spell/spell_to_add

/datum/eldritch_knowledge/spell/on_gain(mob/user)
	var/obj/effect/proc_holder/S = new spell_to_add
	user.mind.AddSpell(S)
	. = ..()

/datum/eldritch_knowledge/spell/on_lose(mob/user)
	user.mind.RemoveSpell(spell_to_add)
	. = ..()

/datum/eldritch_knowledge/curse
	var/timer = 5 MINUTES
	var/list/fingerprints = list()

/datum/eldritch_knowledge/curse/recipe_snowflake_check(list/atoms, loc)
	fingerprints = list()
	for(var/X in atoms)
		var/atom/A = X
		fingerprints |= A.return_fingerprints()
	listclearnulls(fingerprints)
	if(LAZYLEN(fingerprints) == 0)
		return FALSE
	return TRUE

/datum/eldritch_knowledge/curse/on_finished_recipe(mob/living/user,list/atoms,loc)

	var/list/compiled_list = list()

	for(var/mob/living/carbon/human/H in GLOB.alive_mob_list)
		if(fingerprints[md5(H.dna.uni_identity)])
			compiled_list |= H.real_name
			compiled_list[H.real_name] = H

	if(LAZYLEN(compiled_list) == 0)
		to_chat(user, "<span class='warning'>The items don't posses required fingerprints.</span>")
		return

	var/chosen_mob = input("Select the person you wish to curse","Your target") as null|anything in sortList(compiled_list, /proc/cmp_typepaths_asc)
	if(!chosen_mob)
		return ..()
	curse(compiled_list[chosen_mob])
	addtimer(CALLBACK(src, .proc/uncurse, compiled_list[chosen_mob]),timer)
	. = ..()

/datum/eldritch_knowledge/curse/proc/curse(mob/living/chosen_mob)
	return

/datum/eldritch_knowledge/curse/proc/uncurse(mob/living/chosen_mob)
	if(!chosen_mob)
		return

/datum/eldritch_knowledge/summon
	var/mob/living/mob_to_summon


/datum/eldritch_knowledge/summon/on_finished_recipe(mob/living/user,list/atoms,loc)
	. = ..()
	var/mob/living/summoned = new mob_to_summon(loc)
	message_admins("[summoned.name] is being summoned by [user.real_name] in [loc]")
	var/list/mob/dead/observer/candidates = pollCandidatesForMob("Do you want to play as a [summoned.real_name]", ROLE_ECULTIST, null, ROLE_ECULTIST, 50,summoned)
	if(!LAZYLEN(candidates))
		return
	var/mob/dead/observer/C = pick(candidates)
	message_admins("[key_name_admin(C)] has taken control of ([key_name_admin(summoned)]).")
	summoned.ghostize(0)
	summoned.key = C.key

	to_chat(summoned,"<span class='warning'>You are bound to [user.real_name]'s' will! Don't let your master die, protect him at all cost!</span>")
///////////////
///Base lore///
///////////////

/datum/eldritch_knowledge/spell/basic
	name = "Break of dawn"
	desc = "Starts your journey in the mansus. Allows you to transmute a soul bottle using a glass shard and a broken drinking bottle. Use a soul bottle on a dead person to harvest their soul. Use it then on ancient lore to  gain a charge. You can additionally harvest pierced realities. It takes a minute to harvest them and after you do so they are visible to everyone."
	gain_text = "Gates of mansus open up to your mind."
	next_knowledge = list(/datum/eldritch_knowledge/base_rust,/datum/eldritch_knowledge/base_ash,/datum/eldritch_knowledge/base_flesh)
	cost = 0
	spell_to_add = /obj/effect/proc_holder/spell/targeted/touch/mansus_grasp
	required_atoms = list(/obj/item/living_heart)
	route = "Start"

/datum/eldritch_knowledge/spell/basic/recipe_snowflake_check(list/atoms, loc)
	. = ..()
	for(var/obj/item/living_heart/LH in atoms)
		if(!LH.target)
			var/datum/objective/A = new
			LH.target = A.find_target()//easy way, i dont feel like copy pasting that entire block of code
			qdel(A)
			return FALSE
		for(var/mob/living/carbon/human/H in atoms)
			if(H.stat == DEAD)
				return TRUE
	return FALSE

/datum/eldritch_knowledge/spell/basic/on_finished_recipe(mob/living/user, list/atoms, loc)
	. = ..()
	for(var/X in user.GetAllContents())
		if(!istype(X,/obj/item/forbidden_book))
			continue
		var/obj/item/forbidden_book/FB = X
		FB.charge++
	for(var/obj/item/living_heart/LH in atoms)
		var/mob/living/carbon/human/H = LH.target.current
		H.gib()
		var/datum/antagonist/ecult/EC = user.mind.has_antag_datum(/datum/antagonist/ecult)
		EC.total_sacrifices++
		var/datum/objective/A = new
		LH.target = A.find_target()//easy way, i dont feel like copy pasting that entire block of code
		qdel(A)
		to_chat(user,"<span class='warning'>Your new target has been selected, go and sacrifice [LH.target.current.real_name]!</span>")

/datum/eldritch_knowledge/spell/basic/cleanup_atoms(list/atoms)
	return

/datum/eldritch_knowledge/living_heart
	name = "Living Heart"
	desc = "Allows you to create additional living hearts, using a heart, a pool of blood and a poppy. Living hearts when used on a transmutation rune will grant you a person to hunt and sacrifice on the rune. Every sacrifice gives you an additional charge in the book."
	gain_text = "Gates of mansus open up to your mind."
	cost = 0
	required_atoms = list(/obj/item/organ/heart,/obj/effect/decal/cleanable/blood,/obj/item/reagent_containers/food/snacks/grown/poppy)
	result_atoms = list(/obj/item/living_heart)
	route = "Start"
