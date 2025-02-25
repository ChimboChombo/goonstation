/mob/dead/target_observer/hivemind_observer
	var/datum/abilityHolder/changeling/hivemind_owner
	var/can_exit_hivemind_time = 0
	var/last_attack = 0
	/// Hivemind pointing uses an image rather than a decal
	var/static/point_img = null

	New()
		. = ..()
		if (!point_img)
			point_img = image('icons/mob/screen1.dmi', icon_state = "arrow")
		REMOVE_ATOM_PROPERTY(src, PROP_MOB_EXAMINE_ALL_NAMES, src)

	say_understands(var/other)
		return 1

	say(var/message)
		message = trim(copytext(sanitize(message), 1, MAX_MESSAGE_LEN))

		if (!message)
			return

		if (dd_hasprefix(message, "*"))
			return

		logTheThing("diary", src, null, "(HIVEMIND): [message]", "hivesay")

		if (src.client && src.client.ismuted())
			boutput(src, "You are currently muted and may not speak.")
			return

		. = src.say_hive(message, hivemind_owner)

	stop_observing()
		set hidden = 1

	disposing()
		observers -= src
		hivemind_owner?.hivemind -= src
		..()

	click(atom/target, params)
		if (src.client.check_key(KEY_POINT))
			point_at(target)
			return
		if (try_launch_attack(target))
			return
		..()

	update_cursor()
		..()
		if (src.client)
			if (src.client.check_key(KEY_POINT))
				src.set_cursor('icons/cursors/point.dmi')
				return

	point_at(atom/target)
		make_hive_point(target, color="#e2a059")

	/// Like make_point, but the point is an image that is only displayed to hivemind members
	proc/make_hive_point(atom/movable/target, color="#ffffff", time=2 SECONDS)
		var/image/point = image(point_img, loc = target, layer = EFFECTS_LAYER_1)
		point.color = color
		var/list/client/viewers = new
		for (var/mob/member in hivemind_owner.get_current_hivemind())
			if (!member.client)
				continue
			boutput(member, "<span class='game hivesay'><span class='prefix'>HIVEMIND: </span><b>[src]</b> points to [target].</span>")
			member.client.images += point
			viewers += member.client
		var/matrix/M = matrix()
		M.Translate((hivemind_owner.owner.x - target.x)*32, (hivemind_owner.owner.y - target.y)*32)
		point.transform = M
		animate(point, transform=null, time=2)
		SPAWN(time)
			for (var/client/viewer in viewers)
				viewer.images -= point
			qdel(point)
		return point

	proc/try_launch_attack(atom/shoot_target)
		.= 0
		if (isabomination(hivemind_owner.owner) && world.time > (last_attack + src.combat_click_delay))
			var/obj/projectile/proj = initialize_projectile_ST(target, new /datum/projectile/special/acidspit, shoot_target)
			if (proj) //ZeWaka: Fix for null.launch()
				proj.launch()
				last_attack = world.time
				playsound(src, 'sound/weapons/flaregun.ogg', 30, 0.1, 0, 2.6)
				.= 1

	proc/boot()
		var/mob/dead/observer/my_ghost = new(src.corpse)

		if (!src.corpse)
			my_ghost.name = src.name
			my_ghost.real_name = src.real_name

		if (corpse)
			corpse.ghost = my_ghost
			my_ghost.corpse = corpse

		my_ghost.delete_on_logout = my_ghost.delete_on_logout_reset

		if (src.client)
			src.removeOverlaysClient(src.client)
			client.mob = my_ghost

		if (src.mind)
			mind.transfer_to(my_ghost)

		var/ASLoc = pick_landmark(LANDMARK_OBSERVER, locate(1, 1, 1))
		if (target)
			var/turf/T = get_turf(target)
			if (T && (!isghostrestrictedz(T.z) || isghostrestrictedz(T.z) && (restricted_z_allowed(my_ghost, T) || my_ghost.client && my_ghost.client.holder)))
				my_ghost.set_loc(T)
			else
				if (ASLoc)
					my_ghost.set_loc(ASLoc)
				else
					my_ghost.z = 1
		else
			if (ASLoc)
				my_ghost.set_loc(ASLoc)
			else
				my_ghost.z = 1

		observers -= src
		qdel(src)

	proc/set_owner(var/datum/abilityHolder/changeling/new_owner)
		if(!istype(new_owner)) return 0
		//DEBUG_MESSAGE("Calling set_owner on [src] with abilityholder belonging to [new_owner.owner]")

		//If we had an owner then remove ourselves from the their hivemind
		if(hivemind_owner)
			//DEBUG_MESSAGE("Removing [src] from [hivemind_owner.owner]'s hivemind.")
			hivemind_owner.hivemind -= src

		//DEBUG_MESSAGE("Adding [src] to new owner [new_owner.owner]'s hivemind.")
		//Add ourselves to the new owner's hivemind
		hivemind_owner = new_owner
		new_owner.hivemind |= src
		//...and transfer the observe stuff accordingly.
		//DEBUG_MESSAGE("Setting new observe target: [new_owner.owner]")
		set_observe_target(new_owner.owner)

		return 1

/mob/dead/target_observer/hivemind_observer/proc/regain_control()
	set name = "Retake Control"
	set category = "Changeling"
	usr = src

	if(hivemind_owner && hivemind_owner.master == src)
		if(hivemind_owner.return_control_to_master())
			qdel(src)

/mob/dead/target_observer/hivemind_observer/verb/exit_hivemind()
	set name = "Exit Hivemind"
	set category = "Commands"
	usr = src

	if(world.time >= can_exit_hivemind_time && hivemind_owner && hivemind_owner.master != src)
		hivemind_owner.hivemind -= src
		boutput(src, "<span class='alert'>You have parted with the hivemind.</span>")
		src.boot()
	else
		boutput(src, "<span class='alert'>You are not able to part from the hivemind at this time. You will be able to leave in [(can_exit_hivemind_time/10 - world.time/10)] seconds.</span>")

