#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef uint8_t bool;
#define true 1
#define false 0

typedef struct {
    //  BIOS Parameter Block
    uint8_t  BootJumpInstruction[3];
    uint8_t  OEMIdentifier[8];
    uint16_t BytesPerSector;
    uint8_t  SectorsPerCluster;
    uint16_t ReservedSectors;
    uint8_t  FATCount;
    uint16_t DirEntryCount;
    uint16_t TotalSectors;
    uint8_t  MediaDescriptorType;
    uint16_t SectorsPerFAT;
    uint16_t SectorsPerTrack;
    uint16_t Heads;
    uint32_t HiddenSectors;
    uint32_t LargeSectorCount;

    // Extended Boot Record
    uint8_t  PhysicalDriveNumber;
    uint8_t  Reserved;
    uint8_t  ExtendedBootSignature;
    uint32_t VolumeID;
    uint8_t  VolumeLabel[11];
    uint8_t  FileSystemType[8];
} __attribute__((packed)) BootSector;
// Packed ensures that gcc doesn't add padding to the struct, as this would cause the struct to be misaligned (not matching) with the actual data on disk

typedef struct {
    uint8_t  Name[11];
    uint8_t  Attributes;
    uint8_t  Reserved;
    uint8_t  CreationTimeTenths;
    uint16_t CreationTime;
    uint16_t CreationDate;
    uint16_t AccessDate;
    uint16_t FirstClusterHigh;
    uint16_t ModificationTime;
    uint16_t ModificationDate;
    uint16_t FirstClusterLow;
    uint32_t Size;

} __attribute__((packed)) DirectoryEntry;

BootSector g_BootSector;
uint8_t g_Fat = NULL;
DirectoryEntry* g_RootDirectory = NULL;

/*
- Read the boot sector from the disk and store it in g_BootSector in memory.
- We can now access the boot sector data and any relevant information needed easily.
*/
bool readBootSector(FILE* disk) {
    return fread(&g_BootSector, sizeof(g_BootSector), 1, disk) > 0;
}

/*
- Read `count` sectors starting from LBA `lba` and store them in `bufferOut`.
- The disk is assumed to be open and the file pointer is at the start of the disk.
*/
bool readSectors(FILE* disk, uint32_t lba, uint32_t count, void* bufferOut) {
    bool ok = true;
    ok = ok && (fseek(disk, lba * g_BootSector.BytesPerSector, SEEK_SET) == 0);
    ok = ok && (fread(bufferOut, g_BootSector.BytesPerSector, count, disk) == count);
    return ok;
}

/*
- Allocate memory for the FAT region. g_Fat is then a pointer to the FAT Region in memory.
- Then read the FAT Region from the disk and store it in g_Fat.
- We pass ReservedSectors as the LBA because the FAT region comes after the reserved section.
*/
bool readFat(FILE* disk) {
    g_Fat = (uint8_t*) malloc(g_BootSector.SectorsPerFAT * g_BootSector.BytesPerSector);
    return readSectors(disk, g_BootSector.ReservedSectors, g_BootSector.SectorsPerFAT, g_Fat);
}

/*
- Allocate and assign memory for the root directory.
- Calculations are done to determine the LBA of the root directory, and the number of sectors it occupies.
*/
bool readRootDirectory(FILE* disk) {
    uint32_t lba = g_BootSector.ReservedSectors + g_BootSector.FATCount * g_BootSector.SectorsPerFAT;
    uint32_t size = g_BootSector.DirEntryCount * sizeof(DirectoryEntry);
    uint32_t sectors = (size / g_BootSector.BytesPerSector);
    if (size % g_BootSector.BytesPerSector > 0) 
        sectors++;
    g_RootDirectory = (DirectoryEntry*) malloc(sectors * g_BootSector.BytesPerSector);
    return readSectors(disk, lba, sectors, g_RootDirectory);
}

DirectoryEntry* findFile(const char* name) {
    for (uint32_t i = 0; i < g_BootSector.DirEntryCount; i++) {
        if (memcmp(g_RootDirectory[i].Name, name, 11) == 0) {
            return &g_RootDirectory[i];
        }
    }
    return NULL;
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

    if (!readFat(disk)) {
        fprintf(stderr, "Failed to read FAT\n");
        free(g_Fat);
        return -3;
    }

    if (!readRootDirectory(disk)) {
        fprintf(stderr, "Failed to read root directory\n");
        free(g_Fat);
        free(g_RootDirectory);
        return -4;
    }

    DirectoryEntry* fileEntry = findFile(argv[2]);
    if (!fileEntry) {
        fprintf(stderr, "File not found: %s\n", argv[2]);
        free(g_Fat);
        free(g_RootDirectory);
        return -5;
    }

    free(g_Fat);
    free(g_RootDirectory);
    return 0;
}