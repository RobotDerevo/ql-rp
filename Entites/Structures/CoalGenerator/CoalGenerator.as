// Lever.as

#include "MechanismsCommon.as";
#include "GenericButtonCommon.as";
#include "HoverMessage.as";
#include "Help.as";
#include "Hitters.as";

class Lever : Component
{
	Lever(Vec2f position)
	{
		x = position.x;
		y = position.y;
	}
};

void onInit(CBlob@ this)
{
	// used by BuilderHittable.as
	this.Tag("builder always hit");

	// used by BlobPlacement.as
	this.Tag("place norotate");
	this.set_u16("max_w", 350);
	this.set_u16("fuel_for_sec", 5);
	this.getSprite().SetAnimation("default");

	// used by TileBackground.as
	this.set_TileType("background tile", CMap::tile_wood_back);

	// background, let water overlap
	this.getShape().getConsts().waterPasses = true;

	this.addCommandID("toggle");
	this.addCommandID("toggle client");
	this.addCommandID("animation turn on");
	this.addCommandID("animation turn off");
	this.addCommandID("fuel message");

	AddIconToken("$lever_0$", "Lever.png", Vec2f(16, 16), 4);
	AddIconToken("$lever_1$", "Lever.png", Vec2f(16, 16), 5);
	CSprite@ sprite = this.getSprite();
	sprite.SetEmitSound("CoalGenerator_loop.ogg");
	sprite.SetEmitSoundPaused(true);

	this.SetLight(false);
	this.SetLightRadius(128.0f);
	this.SetLightColor(SColor(255, 255, 240, 171));
	this.Tag("bomberman_style");
	this.set_f32("map_bomberman_width", 24.0f);
	this.set_f32("explosive_radius", 64.0f);
	this.set_f32("explosive_damage", 10.0f);
	this.set_u8("custom_hitter", Hitters::keg);
	this.set_string("custom_explosion_sound", "Entities/Items/Explosives/KegExplosion.ogg");
	this.set_f32("map_damage_radius", 72.0f);
	this.set_f32("map_damage_ratio", 1.0f);
	this.set_bool("map_damage_raycast", true);
}


void onInit(CSprite@ this)
{
	this.SetZ(-50); //background

	//init flame layer
	CSpriteLayer@ fire = this.addSpriteLayer("fire_animation_large", "Entities/Effects/Sprites/LargeFire.png", 16, 16, -1, -1);

	if (fire !is null)
	{
		fire.SetRelativeZ(1);
		fire.SetOffset(Vec2f(-2.0f, -6.0f));
		{
			Animation@ anim = fire.addAnimation("fire", 6, true);
			anim.AddFrame(1);
			anim.AddFrame(2);
			anim.AddFrame(3);
		}
		fire.SetVisible(true);
	}
}

void onSetStatic(CBlob@ this, const bool isStatic)
{
	if (!isStatic || this.exists("component")) return;

	Vec2f position = this.getPosition() / 8 + Vec2f(0, -3);

	Lever component(position);
	this.set("component", component);

	this.set_u8("state", 0);

	if (isServer() && this.hasTag("fuel"))
	{
		//first output

		MapPowerGrid@ grid;
		if (!getRules().get("power grid", @grid)) return;

		grid.setAll(
		component.x,                        // x
		component.y,                        // y
		TOPO_NONE,                          // input topology
		TOPO_CARDINAL,                      // output topology
		INFO_SOURCE,                        // information
		0,                                  // power
		0);                                 // id


	}

	CSprite@ sprite = this.getSprite();
	if (sprite is null) return;

	sprite.SetFacingLeft(false);
	sprite.SetZ(-50);

	CSpriteLayer@ layer = sprite.addSpriteLayer("background", "Lever.png", 8, 8);
	layer.addAnimation("default", 0, false);
	layer.animation.AddFrame(2);
	layer.SetRelativeZ(-1);
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (!canSeeButtons(this, caller)) return;

	if (!this.isOverlapping(caller) || !this.getShape().isStatic()) return;

	u8 state = this.get_u8("state");
	string description = (state > 0)? "Deactivate" : "Activate";

	CButton@ button = caller.CreateGenericButton(
	"$lever_"+state+"$",                        // icon token
	Vec2f(0, 4),                                 // button offset
	this,                                       // button attachment
	this.getCommandID("toggle"),                // command id
	description);                               // description

	button.radius = 8.0f;
	button.enableRadius = 20.0f;
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("toggle") && isServer())
	{

		CPlayer@ p = getNet().getActiveCommandPlayer();
		if (p is null) return;

		CBlob@ caller = p.getBlob();
		if (caller is null) return;

		if(!this.hasTag("fuel")) {this.SendCommand(this.getCommandID("fuel message")); return;}

		// range check
		if (this.getDistanceTo(caller) > 20.0f) return;

		Component@ component = null;
		if (!this.get("component", @component)) return;

		MapPowerGrid@ grid;
		if (!getRules().get("power grid", @grid)) return;

		u8 state = this.get_u8("state") == 0? 1 : 0;
		u8 info = state == 0? INFO_SOURCE : INFO_SOURCE | INFO_ACTIVE;

		this.set_u8("state", state);
		this.Sync("state", true);




		grid.setInfo(
		component.x,                        // x
		component.y,                        // y
		info);                              // information

		this.set_Vec2f("energy_wire", Vec2f(component.x , component.y));

	}
	if (cmd == this.getCommandID("toggle") && isClient())
	{
		CSprite@ sprite = this.getSprite();
		if (sprite is null) return;

		sprite.SetFrameIndex(this.get_u8("state"));
		sprite.PlaySound("LeverToggle.ogg");
		
	}
	if (cmd == this.getCommandID("animation turn on") && isClient())
	{  
		CSprite@ sprite = this.getSprite();
		sprite.SetEmitSoundPaused(false);
		this.Tag("exploding");
		if(getGameTime() % 7 == 0) {
			makeSteamParticle(this, Vec2f(0.5f, -0.25f));
		} // every 7 ticks
		this.getSprite().SetAnimation("fire");
	}
	if (cmd == this.getCommandID("animation turn off") && isClient())
	{
		CSprite@ sprite = this.getSprite();
		this.getSprite().SetAnimation("default");
		sprite.SetEmitSoundPaused(true);
	}
	if (cmd == this.getCommandID("fuel message") && isClient()) {
		FuelMessage@ msg = FuelMessage();
		add_message(@msg, true);
	}
}

bool canBePickedUp(CBlob@ this, CBlob@ byBlob)
{
	return false;
}

void makeSteamParticle(CBlob@ this, const Vec2f vel, const string filename = "LargeSmoke")
{
	if (!isClient()) return;

	const f32 rad = this.getRadius();
	Vec2f random = Vec2f(XORRandom(128) - 64, XORRandom(128) - 64) * 0.015625f * rad;
	ParticleAnimated(filename, this.getPosition() + random, vel, float(XORRandom(360)), 1.0f, 2 + XORRandom(3), -0.1f, false);
}

void onTick(CBlob@ this)
{
	u8 state = this.get_u8("state") == 0? 1 : 0;

	if(this.hasBlob("mat_wood", this.get_u16("fuel_for_sec"))) this.Tag("fuel");
	else this.Untag("fuel");


	if(state == 0 && this.hasTag("fuel")) {
		this.SendCommand(this.getCommandID("animation turn on"));
		this.AddScript("ExplodeOnDie.as"); //prevents cheating
		this.SetLight(true);
		if(getGameTime() % 30 == 0) {
			this.TakeBlob("mat_wood", this.get_u16("fuel_for_sec"));
		} //every second
	}
	else {
		this.SendCommand(this.getCommandID("animation turn off"));
		this.SetLight(false);
		this.RemoveScript("ExplodeOnDie.as");
		this.set_u8("state", 1);
		this.Sync("state", true);
		Component@ component = null;
		if (!this.get("component", @component)) return;

		MapPowerGrid@ grid;
		if (!getRules().get("power grid", @grid)) return;

		u8 state = this.get_u8("state") == 0? 1 : 0;
		u8 info = state == 0? INFO_SOURCE : INFO_SOURCE | INFO_ACTIVE;


		this.set_u8("state", state);
		this.Sync("state", true);





		grid.setInfo(
		component.x,                        // x
		component.y,                        // y
		info);
	}
}
