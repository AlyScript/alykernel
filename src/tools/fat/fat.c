#include <stdint.h>
#include <stdio.h>

typedef uint8_t bool;
#define true 1
#define false 0

typedef struct {
    //  BIOS Parameter Block
    uint8_t BootJumpInstruction[3];
    uint8_t OEMIdentifier[8];
    uint16_t BytesPerSector;
    uint8_t SectorsPerCluster;
    uint16_t ReservedSectors;
    uint8_t FATCount;
    uint16_t DirEntryCount;
    uint16_t TotalSectors;
    uint8_t MediaDescriptorType;
    uint16_t SectorsPerFAT;
    uint16_t SectorsPerTrack;
    uint16_t Heads;
    uint32_t HiddenSectors;
    uint32_t LargeSectorCount;

    // Extended Boot Record
    uint8_t PhysicalDriveNumber;
    uint8_t Reserved;
    uint8_t ExtendedBootSignature;
    uint32_t VolumeID;
    uint8_t VolumeLabel[11];
    uint8_t FileSystemType[8];
} __attribute__((packed)) BootSector;
// Packed ensures that gcc doesn't add padding to the struct, as this would cause the struct to be misaligned (not matching) with the actual data on disk

BootSector g_BootSector;

bool readBootSector(FILE* disk) {
    return fread(&g_BootSector, sizeof(g_BootSector), 1, disk) > 0;
}

int main(int argc, char *argv[]) {
        if (argc < 3) {
            printf("Usage: %s <disk_image> <path>\n", argv[0]);
            return -1;
        }

    FILE *disk = fopen(argv[1], "rb");
    if (!disk) {
        fprintf("Failed to open disk image %s\n", argv[1]);
        return -1;
    }

    if (!readBootSector(disk)) {
        fprintf(stderr, "Failed to read boot sector\n");
        return -2;
    }


    return 0;
}