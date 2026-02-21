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
	{ 0x79a1bd53, "regcache_cache_only" },
	{ 0x882fab7, "regcache_sync" },
	{ 0x3e10d84a, "regmap_write" },
	{ 0xa7961b50, "devm_request_threaded_irq" },
	{ 0xb83f54d3, "gpiod_set_value" },
	{ 0xae0da4b6, "of_property_read_variable_u32_array" },
	{ 0x5d2ffc1d, "regmap_get_max_register" },
	{ 0xc5b6f236, "queue_work_on" },
	{ 0xb742fd7, "simple_strtol" },
	{ 0x47a6dc2d, "i2c_match_id" },
	{ 0x8cedd452, "devm_input_allocate_device" },
	{ 0x9953258d, "gpiod_to_irq" },
	{ 0x29550d5c, "input_unregister_device" },
	{ 0x37a0cba, "kfree" },
	{ 0xc3055d20, "usleep_range_state" },
	{ 0xbda912a8, "devm_gpiod_get_optional" },
	{ 0x34db050b, "_raw_spin_lock_irqsave" },
	{ 0xf27c73f8, "devm_snd_soc_register_component" },
	{ 0x122c3a7e, "_printk" },
	{ 0xa1ac31af, "input_register_device" },
	{ 0x87c34f77, "__devm_regmap_init_i2c" },
	{ 0xf0fdf6cb, "__stack_chk_fail" },
	{ 0xb2fcb56d, "queue_delayed_work_on" },
	{ 0x36a2c31, "devm_free_irq" },
	{ 0xfee0e62b, "seeed_voice_card_register_set_clock" },
	{ 0xed2df188, "i2c_register_driver" },
	{ 0xdc2f589d, "snd_soc_info_volsw" },
	{ 0x856a7871, "snd_soc_unregister_component" },
	{ 0x16736258, "_dev_err" },
	{ 0x7802362d, "gpiod_direction_input" },
	{ 0x4dfa8d4b, "mutex_lock" },
	{ 0xa0fe4fd4, "input_set_capability" },
	{ 0xca89330a, "snd_soc_add_component_controls" },
	{ 0x757bcf5e, "sysfs_create_group" },
	{ 0xcefb0c9f, "__mutex_init" },
	{ 0xd35cce70, "_raw_spin_unlock_irqrestore" },
	{ 0x81df7931, "_dev_warn" },
	{ 0x7641e911, "snd_soc_dapm_add_routes" },
	{ 0x78d6561b, "input_event" },
	{ 0xa18c0552, "sysfs_remove_group" },
	{ 0x9f4f7542, "snd_soc_get_volsw" },
	{ 0x3fa4f061, "regmap_read" },
	{ 0x2bd8c7b7, "snd_soc_put_volsw" },
	{ 0x3213f038, "mutex_unlock" },
	{ 0x9fa7184a, "cancel_delayed_work_sync" },
	{ 0xc6f46339, "init_timer_key" },
	{ 0x89690c70, "snd_soc_dapm_new_controls" },
	{ 0x3c12dfe, "cancel_work_sync" },
	{ 0xffeedf6a, "delayed_work_timer_fn" },
	{ 0xfcdc7a76, "regcache_cache_bypass" },
	{ 0xa65c6def, "alt_cb_patch_nops" },
	{ 0x244227cc, "regmap_update_bits_base" },
	{ 0x1c43a8f, "kmalloc_trace" },
	{ 0x71d6144a, "i2c_del_driver" },
	{ 0xe0cdedb7, "snd_soc_dai_active" },
	{ 0xf9a482f9, "msleep" },
	{ 0x42b07433, "kmalloc_caches" },
	{ 0x2d3385d3, "system_wq" },
	{ 0x67a35d9, "module_layout" },
};

MODULE_INFO(depends, "snd-soc-core,regmap-i2c,snd-soc-seeed-voicecard");

MODULE_ALIAS("i2c:ac108_0");
MODULE_ALIAS("i2c:ac108_1");
MODULE_ALIAS("i2c:ac108_2");
MODULE_ALIAS("i2c:ac108_3");
MODULE_ALIAS("i2c:ac101");
MODULE_ALIAS("of:N*T*Cx-power,ac108_0");
MODULE_ALIAS("of:N*T*Cx-power,ac108_0C*");
MODULE_ALIAS("of:N*T*Cx-power,ac108_1");
MODULE_ALIAS("of:N*T*Cx-power,ac108_1C*");
MODULE_ALIAS("of:N*T*Cx-power,ac108_2");
MODULE_ALIAS("of:N*T*Cx-power,ac108_2C*");
MODULE_ALIAS("of:N*T*Cx-power,ac108_3");
MODULE_ALIAS("of:N*T*Cx-power,ac108_3C*");
MODULE_ALIAS("of:N*T*Cx-power,ac101");
MODULE_ALIAS("of:N*T*Cx-power,ac101C*");

MODULE_INFO(srcversion, "42CCF7C23EB65AFAFA96183");
