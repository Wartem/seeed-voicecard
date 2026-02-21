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



static const struct modversion_info ____versions[]
__used __section("__versions") = {
	{ 0x882fab7, "regcache_sync" },
	{ 0x3e10d84a, "regmap_write" },
	{ 0xe08736b, "devm_kmalloc" },
	{ 0xa92ed5d, "snd_soc_component_read" },
	{ 0x616899e2, "snd_soc_put_enum_double" },
	{ 0xb1a1b212, "devm_clk_get" },
	{ 0xae2df1f0, "snd_soc_component_write" },
	{ 0xf27c73f8, "devm_snd_soc_register_component" },
	{ 0x7c9a7371, "clk_prepare" },
	{ 0x122c3a7e, "_printk" },
	{ 0x87c34f77, "__devm_regmap_init_i2c" },
	{ 0xacf0c5ed, "snd_soc_get_enum_double" },
	{ 0xed2df188, "i2c_register_driver" },
	{ 0xdc2f589d, "snd_soc_info_volsw" },
	{ 0x973ec67, "snd_ctl_boolean_mono_info" },
	{ 0x856a7871, "snd_soc_unregister_component" },
	{ 0x16736258, "_dev_err" },
	{ 0x7bec6e8, "snd_soc_dapm_put_volsw" },
	{ 0x2f81a1f8, "of_find_property" },
	{ 0xca89330a, "snd_soc_add_component_controls" },
	{ 0x7641e911, "snd_soc_dapm_add_routes" },
	{ 0xd60751e5, "snd_soc_info_enum_double" },
	{ 0xe2d5255a, "strcmp" },
	{ 0x9f4f7542, "snd_soc_get_volsw" },
	{ 0x2bd8c7b7, "snd_soc_put_volsw" },
	{ 0xd487906e, "snd_soc_component_update_bits" },
	{ 0x89690c70, "snd_soc_dapm_new_controls" },
	{ 0xb6e6d99d, "clk_disable" },
	{ 0x244227cc, "regmap_update_bits_base" },
	{ 0x9d1d0548, "snd_soc_dapm_get_volsw" },
	{ 0x71d6144a, "i2c_del_driver" },
	{ 0x815588a6, "clk_enable" },
	{ 0xeb711ae7, "snd_soc_params_to_bclk" },
	{ 0xf9a482f9, "msleep" },
	{ 0xe56a9336, "snd_pcm_format_width" },
	{ 0xb077e70a, "clk_unprepare" },
	{ 0x67a35d9, "module_layout" },
};

MODULE_INFO(depends, "snd-soc-core,regmap-i2c,snd,snd-pcm");

MODULE_ALIAS("i2c:wm8960");
MODULE_ALIAS("of:N*T*Cwlf,wm8960");
MODULE_ALIAS("of:N*T*Cwlf,wm8960C*");

MODULE_INFO(srcversion, "64A9B8B57C48A8F6DD94B1A");
