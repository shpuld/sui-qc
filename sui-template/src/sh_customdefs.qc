//shared definitions

#define printf(x, ...) print(sprintf(x, __VA_ARGS__))


void() precache_everything =
{
	precache_sound("demon/dland2.wav");
	precache_model("models/testplayer.iqm");
};