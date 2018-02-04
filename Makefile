uefi.img: main.efi
	dd if=/dev/zero of=uefi.img bs=512 count=93761
	sgdisk -o uefi.img
	sgdisk -n 1:2048:93727 -t 0:ef00 uefi.img
	dd if=/dev/zero of=part.img bs=512 count=91680
	mkfs.fat -F 32 -v part.img
	mcopy -i part.img main.efi startup.nsh ::
	dd if=part.img of=uefi.img bs=512 count=91680 seek=2048 conv=notrunc

main.efi: main.so
	objcopy -j .text -j .sdata -j .data -j .dynamic -j .dynsym -j .rel -j .rela -j .reloc \
		--target=efi-app-x86_64 main.so main.efi

main.so: main.o
	ld main.o /usr/lib/crt0-efi-x86_64.o -nostdlib -znocombreloc \
		-T/usr/lib/elf_x86_64_efi.lds -shared -Bsymbolic \
		-L/usr/lib -lgnuefi -lefi -o main.so

main.o:
	gcc main.c -c -fno-stack-protector -fPIC -fshort-wchar -mno-red-zone \
		-I/usr/include/efi -I/usr/include/efi/x86_64 \
		-DEFI_FUNCTION_WRAPPER -o main.o

.PHONY: run
run:
	qemu-system-x86_64 -cpu qemu64 -enable-kvm \
		-drive if=pflash,format=raw,unit=0,file=/usr/share/ovmf/x64/OVMF_CODE.fd,readonly=on \
		-drive if=pflash,format=raw,unit=1,file=/usr/share/ovmf/x64/OVMF_VARS.fd \
		-drive file=uefi.img,if=ide \
		-net none

.PHONY: clean
clean:
	rm -f main.efi main.so main.o uefi.img part.img
