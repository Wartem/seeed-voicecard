#include <linux/module.h>
#define INCLUDE_VERMAGIC
#include <linux/build-salt.h>
#include <linux/elfnote-lto.h>
#include <linux/export-internal.h>
#include <linux/vermagic.h>
#include <linux/compiler.h>

#ifdef CONFIG_UNWINDER_ORC
#include <asm/orc_header.h>
ORC_HEADER;
#endif

BUILD_SALT;
BUILD_LTO_INFO;

MODULE_INFO(vermagic, VERMAGIC_STRING);
MODULE_INFO(name, KBUILD_MODNAME);

__visible struct module __this_module
__section(".gnu.linkonce.this_module") = {
	.name = KBUILD_MODNAME,
	.init = init_module,
#ifdef CONFIG_MODULE_UNLOAD
	.exit = cleanup_module,
#endif
	.arch = MODULE_ARCH_INIT,
};

#ifdef CONFIG_RETPOLINE
MODULE_INFO(retpoline, "Y");
#endif

KSYMTAB_FUNC(seeed_voice_card_register_set_clock, "", "");

SYMBOL_CRC(seeed_voice_card_register_set_clock, 0xfee0e62b, "");

static const struct modversion_info ____versions[]
__used __section("__versions") = {
	{ 0xfb85756, "snd_soc_of_parse_tdm_slot" },
	{ 0x6710d572, "asoc_simple_parse_clk" },
	{ 0xe08736b, "devm_kmalloc" },
	{ 0x929eb52e, "of_node_put" },
	{ 0xae0da4b6, "of_property_read_variable_u32_array" },
	{ 0x9deb2665, "platform_driver_unregister" },
	{ 0xfc292241, "asoc_simple_set_dailink_name" },
	{ 0x656e4a6e, "snprintf" },
	{ 0xc5b6f236, "queue_work_on" },
	{ 0xa57d31dc, "asoc_simple_clean_reference" },
	{ 0xfde07cce, "snd_soc_of_parse_audio_routing" },
	{ 0x7dd56221, "snd_soc_dai_set_sysclk" },
	{ 0x7c9a7371, "clk_prepare" },
	{ 0xb9ef3539, "of_get_next_child" },
	{ 0xf0fdf6cb, "__stack_chk_fail" },
	{ 0x11270b9e, "asoc_simple_parse_card_name" },
	{ 0x1c0f470, "snd_soc_dai_set_bclk_ratio" },
	{ 0xe2777b6e, "of_get_child_by_name" },
	{ 0x75430838, "asoc_simple_canonicalize_platform" },
	{ 0x16736258, "_dev_err" },
	{ 0x2c09b7b6, "__of_parse_phandle_with_args" },
	{ 0x74fb6aad, "asoc_simple_parse_daifmt" },
	{ 0x2f81a1f8, "of_find_property" },
	{ 0xaf9df555, "of_device_is_available" },
	{ 0xf3703e44, "snd_soc_of_get_dai_name" },
	{ 0xdcb764ad, "memset" },
	{ 0x3d8516ce, "asoc_simple_canonicalize_cpu" },
	{ 0xcd32f847, "__platform_driver_register" },
	{ 0x7af7bfc4, "snd_soc_runtime_calc_hw" },
	{ 0x3c12dfe, "cancel_work_sync" },
	{ 0xb6e6d99d, "clk_disable" },
	{ 0x87e3ae00, "snd_soc_pm_ops" },
	{ 0x8165cf4c, "snd_soc_of_parse_audio_simple_widgets" },
	{ 0x815588a6, "clk_enable" },
	{ 0x10607805, "devm_snd_soc_register_card" },
	{ 0x2d3385d3, "system_wq" },
	{ 0xb077e70a, "clk_unprepare" },
	{ 0x67a35d9, "module_layout" },
};

MODULE_INFO(depends, "snd-soc-core,snd-soc-simple-card-utils");

MODULE_ALIAS("of:N*T*Cseeed-voicecard");
MODULE_ALIAS("of:N*T*Cseeed-voicecardC*");

MODULE_INFO(srcversion, "868FD83D0EB7F9B10B4DEFD");
