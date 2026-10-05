/* StarOS x86_64 kernel link script.
 *
 * GRUB loads us as an ELF64 image. Physical == virtual for now: the boot code
 * identity-maps the first 1 GiB with 2 MiB huge pages before entering long
 * mode, so no higher-half offset is applied here yet.
 *
 * Sections are 4 KiB aligned so that each can later be given its own page
 * permissions (read-only .rodata, non-executable .data/.bss) once a real
 * paging layer exists.
 */

ENTRY(start)

SECTIONS
{
	/* Below 1 MiB is BIOS/VGA territory - never load there. */
	. = 1M;

	kernel_start = .;

	/* Must stay first: GRUB only scans the first 32 KiB of the file for the
	 * multiboot2 header, and KEEP stops --gc-sections from dropping it. */
	.boot : ALIGN(4K)
	{
		KEEP(*(.multiboot_header))
	}

	.text : ALIGN(4K)
	{
		*(.text .text.*)
	}

	.rodata : ALIGN(4K)
	{
		*(.rodata .rodata.*)
	}

	.data : ALIGN(4K)
	{
		*(.data .data.*)
	}

	.bss : ALIGN(4K)
	{
		bss_start = .;
		*(COMMON)
		*(.bss .bss.*)
		bss_end = .;
	}

	/* kernel_end marks the first byte of free physical memory above the
	 * kernel image. The physical memory allocator will start here, so it
	 * must stay the last symbol in the layout. */
	kernel_end = .;

	/DISCARD/ :
	{
		*(.comment)
		*(.note .note.*)
		*(.eh_frame .eh_frame.*)
	}
}
