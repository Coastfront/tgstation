/obj/effect/eldritch
	name = "Generic rune"
	desc = "Weird combination of shapes and symbols etched into the floor itself. The indentation is filled with thick black tar-like fluid."
	anchored = TRUE
	icon_state = ""
	resistance_flags = FIRE_PROOF | UNACIDABLE | ACID_PROOF
	layer = SIGIL_LAYER

/obj/effect/eldritch/attack_hand(mob/living/user)
	. = ..()
	if(.)
		return
	try_activate(user)

/obj/effect/eldritch/proc/try_activate(mob/living/user)
	if(! IS_HERETIC(user) )
		return
	activate(user)

/obj/effect/eldritch/attacked_by(obj/item/I, mob/living/user)
	. = ..()
	if(istype(I,/obj/item/nullrod))
		qdel(src)

/obj/effect/eldritch/proc/activate(mob/living/user)
	// Have fun trying to read this proc.
	var/datum/antagonist/heretic/cultie = user.mind.has_antag_datum(/datum/antagonist/heretic)
	var/list/knowledge = cultie.get_all_knowledge()
	var/list/atoms_in_range = list()

	for(var/atom/atom_in_range in range(1,src))
		if(istype(atom_in_range,/mob/living))
			var/mob/living/living_in_range = atom_in_range
			if(living_in_range.stat != DEAD || living_in_range == user) // we only accept corpses, no living beings allowed.
				continue
		atoms_in_range += atom_in_range

	for(var/X in knowledge)
		var/datum/eldritch_knowledge/current_eldritch_knowledge = X
		var/list/local_required_atoms = current_eldritch_knowledge.required_atoms
		if(!local_required_atoms || local_required_atoms.len == 0)
			continue

		var/list/selected_atoms = list()

		if(!current_eldritch_knowledge.recipe_snowflake_check(atoms_in_range,drop_location(),selected_atoms))
			continue

		for(var/local_required_atom in local_required_atoms)
			local_required_atoms[local_required_atom] = FALSE

		for(var/local_atom_in_range in atoms_in_range)
			var/atom/first_atom = local_atom_in_range
			for(var/local_required_atom_in_range in local_required_atoms)
				var/list/local_required_atom_list_in_range = local_required_atom_in_range
				if(!is_type_in_list(first_atom,local_required_atom_list_in_range) || local_required_atoms[local_required_atom_in_range] == TRUE)
					continue
				local_required_atoms[local_required_atom_in_range] = TRUE
				selected_atoms |= first_atom

		if(selected_atoms.len == 0)
			continue
		var/skip = FALSE
		for(var/secondary_local_required_atom in local_required_atoms)
			if(local_required_atoms[secondary_local_required_atom] != TRUE)
				skip = TRUE
				break

		if(skip)
			continue
		flick("[icon_state]_active",src)
		playsound(user, 'sound/magic/castsummon.ogg', 75, TRUE)
		current_eldritch_knowledge.on_finished_recipe(user,selected_atoms,loc)
		current_eldritch_knowledge.cleanup_atoms(selected_atoms)
		return
	to_chat(user,"<span class='warning'>Your ritual failed! You used either wrong components or are missing something important!</span>")

/obj/effect/eldritch/big
	name = "Transmutation rune"
	icon = 'icons/effects/96x96.dmi'
	icon_state = "eldritch_rune1"
	pixel_x = -32 //So the big ol' 96x96 sprite shows up right
	pixel_y = -32

/**
  * #Reality smash tracker
  *
  * Stupid fucking list holder, DONT create new ones, it will break the game, this is automnatically created whenever eldritch cultists are created.
  *
  * Tracks relevant data, generates relevant data, useful tool
  */
/datum/reality_smash_tracker
	///list of tracked reality smashes
	var/list/smashes = list()
	///List of mobs with ability to see the smashes
	var/list/targets = list()

/datum/reality_smash_tracker/Destroy(force, ...)
	if(GLOB.reality_smash_track == src)
		stack_trace("/datum/reality_smash_tracker was deleted. Heretics may no longer access any influences. Fix it or call coder support")
	for(var/X in smashes)
		qdel(X)
	for(var/Y in targets)
		targets -= Y
	. = ..()

/**
  * Automatically fixes the target and smash network
  *
  * Fixes any bugs that are caused by late Generate()
  */
/datum/reality_smash_tracker/proc/ReworkNetwork()
	for(var/mind in targets)
		for(var/X in smashes)
			var/obj/effect/reality_smash/reality_smash = X
			reality_smash.AddMind(mind)

/**
  * Generates a set amount of reality smashes based on the N value
  *
  * Automatically creates more reality smashes
  */
/datum/reality_smash_tracker/proc/Generate(var/n)
	var/number = round(max(n * 6,10),1)

	for(var/i in 0 to number)

		var/obj/effect/landmark/L = pick(GLOB.generic_event_spawns + GLOB.landmarks_list)
		var/obj/effect/reality_smash/RS = new(L.drop_location())
		smashes += RS

	ReworkNetwork()

/**
  * Adds a mind to the list of people that can see the reality smashes
  *
  * Use this whenever you want to add someone to the list
  */
/datum/reality_smash_tracker/proc/AddMind(var/datum/mind/M)
	targets |= M
	for(var/X in smashes)
		var/obj/effect/reality_smash/reality_smash = X
		reality_smash.AddMind(M)

/**
  * Removes a mind from the list of people that can see the reality smashes
  *
  * Use this whenever you want to remove someone from the list
  */
/datum/reality_smash_tracker/proc/RemoveMind(var/datum/mind/M)
	targets -= M
	for(var/obj/effect/reality_smash/RS in smashes)
		RS.RemoveMind(M)

/obj/effect/broken_illusion
	name = "Pierced reality"
	icon = 'icons/effects/eldritch.dmi'
	icon_state = "pierced_illusion"

/obj/effect/broken_illusion/examine(mob/user)
	if(!IS_HERETIC(user) && ishuman(user))
		var/mob/living/carbon/human/human_user = user
		to_chat(human_user,"<span class='warning'>Your brain hurts when you look at this!</span>")
		human_user.adjustOrganLoss(ORGAN_SLOT_BRAIN,10)
	. = ..()

/obj/effect/reality_smash
	name = "/improper reality smash"
	icon = 'icons/effects/eldritch.dmi'
	///We cannot use icon_state since this is invisible, functions the same way but with custom behaviour.
	var/image_state = "reality_smash"
	///Who can see us?
	var/list/minds = list()
	///Tracked image
	var/image/img

/obj/effect/reality_smash/Initialize()
	. = ..()
	img = image(icon, src, image_state, OBJ_LAYER)
	generate_name()

/obj/effect/reality_smash/Destroy()

	for(var/datum/mind/cultie in minds)
		if(cultie && cultie.current && cultie.current.client)
			cultie.current.client.images -= img
		//clear the list
		minds -= cultie
	img = null
	new /obj/effect/broken_illusion(drop_location())
	return ..()

///Makes the mind able to see this effect
/obj/effect/reality_smash/proc/AddMind(var/datum/mind/cultie)
	if(cultie.current.client)
		minds |= cultie
		cultie.current.client.images |= img

///Makes the mind not able to see this effect
/obj/effect/reality_smash/proc/RemoveMind(var/datum/mind/cultie)
	if(cultie.current.client)
		minds -= cultie
		cultie.current.client.images -= img

///Generates random name
/obj/effect/reality_smash/proc/generate_name()
	var/static/list/prefix = list("Omniscient","Thundering","Enlightening","Intrusive","Rejectful","Atomized","Subtle","Rising","Lowering","Fleeting","Towering","Blissful")
	var/static/list/postfix = list("Flaw","Presence","Crack","Heat","Cold","Memory","Reminder","Breeze")

	name = pick(prefix) + " " + pick(postfix)
