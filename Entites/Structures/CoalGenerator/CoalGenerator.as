// Lever.as

#include "MechanismsCommon.as";
#include "GenericButtonCommon.as";
#include "HoverMessage.as";
#include "Help.as";

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

	AddIconToken("$lever_0$", "Lever.png", Vec2f(16, 16), 4);
	AddIconToken("$lever_1$", "Lever.png", Vec2f(16, 16), 5);
	CSprite@ sprite = this.getSprite();
	sprite.SetEmitSound("CoalGenerator_loop.ogg");
	sprite.SetEmitSoundPaused(true);

	this.SetLight(false);
	this.SetLightRadius(128.0f);
	this.SetLightColor(SColor(255, 255, 240, 171));
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

		if(!this.hasTag("fuel"))
		{
			FuelMessage@ msg = FuelMessage();
			add_message(@msg, true);
		}


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


	}
	if (cmd == this.getCommandID("toggle client") && isClient())
	{
		CSprite@ sprite = this.getSprite();
		if (sprite is null) return;

		sprite.SetFrameIndex(this.get_u8("state"));
		sprite.PlaySound("LeverToggle.ogg");
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

	CSprite@ sprite = this.getSprite();
	if(state == 0 && this.hasTag("fuel")) {
		this.SetLight(true);
		sprite.SetEmitSoundPaused(false);
		if(getGameTime() % 7 == 0) {
			makeSteamParticle(this, Vec2f(0.5f, -0.25f));
		} // every 7 ticks
		if(getGameTime() % 30 == 0) {
			this.TakeBlob("mat_wood", this.get_u16("fuel_for_sec"));
		} //every second
		this.getSprite().SetAnimation("fire");
	}
	else {
		this.getSprite().SetAnimation("default");
		this.SetLight(true);
		sprite.SetEmitSoundPaused(true);
	}

}