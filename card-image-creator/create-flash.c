#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>

int yearfuzz = 0; // used for debugging; added to all years (set to -2, e.g.)

typedef struct _event_entry {
  char *filename;
  int id;
  int bitpattern;
  int day;
  int month;
  int year;
} event_entry;

char *sox_cmd = "sox -v %.2f %s -r 10000 -c 1 -e unsigned-integer -b 16 -t raw %s 2>&1|grep clip >/dev/null";

char *media_prefix = "media/";
char *cache_prefix = "cache/";

event_entry events[] = {
			/* repeating events, like so:
			 {"some-message.wav",
			 0xID, 0x00, 
			 <day>, <month>, 0xFF},
			 ... where 0xID is >= 0xA0 and < 0xF0
			*/

			/* one-time events, like so:
			{"one-time-message.wav",
			0x<ID>, 0x<BIT>,
			<day>, <mon>, <year> },
			... where 0xID >= 0x10 (and < max ram byte for PIC),
			    and 0x<BIT> is a bit mask in that byte to refer to
			    this specific event (0x01, 0x02, 0x04, 0x08.. 0x80)
			    and 'year' is a two-digit year
			*/


			{ NULL, 0, 0, 0 }
};
						
char *alarm_song = "alarm.wav";
float alarm_volume = 0.8;
char *firmware_image = "../firmware.bin";
unsigned char firmware_version;

char *media[] = { "0.wav", 
		  "1.wav",
		  "2.wav",
		  "3.wav",
		  "4.wav",
		  "5.wav",
		  "6.wav",
		  "7.wav",
		  "8.wav",
		  "9.wav",
		  "10.wav",
		  "11.wav",
		  "12.wav",
		  "13.wav",
		  "14.wav",
		  "15.wav",
		  "16.wav",
		  "17.wav",
		  "18.wav",
		  "19.wav",
		  "20.wav",
		  "21.wav",
		  "22.wav",
		  "23.wav",
		  "30.wav",
		  "40.wav",
		  "50.wav",
		  "60.wav",
		  "70.wav",
		  "80.wav",
		  "90.wav",
		  "hundredhours.wav",
		  "thetimeis.wav",
		  "setalarmhour.wav",
		  "setalarm.wav",
		  "tensofminutes.wav",
		  "onesofminutes.wav",
		  "settimehour.wav",
		  "settime.wav",
		  "setmonth.wav",
		  "setday.wav",
		  "setdow.wav",
		  "settensofyears.wav",
		  "setonesofyears.wav",
		  "timesetto.wav",
		  "alarmsetto.wav",
		  "january.wav",
		  "february.wav",
		  "march.wav",
		  "april.wav",
		  "may.wav",
		  "june.wav",
		  "july.wav",
		  "august.wav",
		  "september.wav",
		  "october.wav",
		  "november.wav",
		  "december.wav",
		  "sunday.wav",
		  "monday.wav",
		  "tuesday.wav",
		  "wednesday.wav",
		  "thursday.wav",
		  "friday.wav",
		  "saturday.wav",
		  "alarmlight.wav",
		  "alarmstartsearly.wav",
		  "alarmstartsontime.wav",
		  "andtodayis.wav",
		  "birthday.wav",
		  "blue.wav",
		  "deadair.wav",
		  "disabled.wav",
		  "jakes.wav",
		  "jorjs.wav",
		  "oclock.wav",
		  "pauls.wav",
		  "sarahs.wav",
		  "set.wav",
		  "setyear.wav",
		  "sues.wav",
		  "white.wav",
		  /* Any media that is listed in the event list above must 
		   * also be listed here */

		  NULL };

FILE *output_file;
unsigned long directory_pos = 0;
unsigned long media_pos = 100 * 512;	// byte counter to the start of the media blocks.
unsigned char directory[100*512]; // 100 pages of directory/bootimg space (0-99).

int media_id(const char *filename)
{
  char **p = media;
  int idx = 0;
  while (*p) {
    if (!strcmp(filename, *p))
      return idx;
    p++;
    idx++;
  }
  printf("ERROR: unable to determine media id for %s\n", filename);
  exit(-2);
}

unsigned char crc7_calc( unsigned char *buff, unsigned long len )
{
  unsigned char crc, i;
  unsigned long j;

  i = 7;// bit position
  j = 0;// array position
  crc = 0;// 7 bit crc value
  while(!((j == len - 1) && (i == 0)) )// crc7
    {
      if((crc = (crc << 1) | ((buff[j] >> i) & 1 )) & 0x80 ) crc ^= 0x89;
      if( i-- == 0 ){ j++; i = 7; 
      }
    }
  return crc << 1;// shift left once
}

// FIXME: file must be < 16k
unsigned char crc7_file(FILE *f)
{
  unsigned char buf[(0x1b00-4)*2];
  size_t s = fread(buf, 1, sizeof(buf), f);
  if (s != sizeof(buf)) {
    fprintf(stderr, "ERROR: unable to read firmware as one chunk (0x%X/0x%X).\n", s,sizeof(buf));
    fprintf(stderr, "       Rewrite crc7_file to be more sane.\n");
    exit(-6);
  }
  return crc7_calc(buf, sizeof(buf));
}

unsigned char to_bcd(unsigned char v)
{
    return (( v / 10 ) * 16) + (v % 10);
}


// add the given media clip to the flash image, and return the length. We have to do some 
// processing of the media clip in order to make it playable; the PIC firmware will dump the 
// raw bytes down the D/A channel, so we have to prepend command information to the bytes 
// here.
unsigned long add_clip(const char *path, float initial_volume)
{
	size_t s;
	unsigned char buf[512];
	unsigned long length = 0;
	char fullpath[1024], cachepath[1024], cmdbuf[2048];
	FILE *f;
	unsigned long i;
	float volume = initial_volume;
	if (volume == 0)
	  volume = 5.0;
	
	sprintf(fullpath, "%s/%s", media_prefix, path);
	sprintf(cachepath, "%s/%s", cache_prefix, path);

	f = fopen(fullpath, "r");
	if (!f) {
		fprintf(stderr, "Failed to open %s: %d\n", fullpath, errno);
		exit(-1);
	}
	fclose(f);

	// adjust the volume of the clip - as loud as possible without distortion!
	f = fopen(cachepath, "r");
	if (f) {
	  close(f);
	  goto got_one_already;
	}

	while (1) {
	  int res;

	  sprintf(cmdbuf, sox_cmd, volume, fullpath, cachepath);
	  res = system(cmdbuf);
	  if (res == 256) 
	    break;
	  volume -= 0.1;
	  if (volume <= 0.1) {
	    fprintf(stderr, "failed.\n");
	    exit(-6);
	  }
	  printf(" - processed at volume %.2f\n", volume);
	}
 got_one_already:
	f = fopen(cachepath, "r");
	if (!f) {
	  fprintf(stderr, "Failed to open tmp path %s: %d\n", cachepath, errno);
	  exit(-1);
	}
	printf(" - starting at media pos %lu\n", media_pos);
	fseek(output_file, media_pos, SEEK_SET);
	while (1) {
		s = fread(buf, 1, 512, f);
		if (!s)
			break;
		for (i=0; i<s; i+=2) {
			unsigned long val = (buf[i+1] << 8) + buf[i];
			val >>= 4; // make it a 12-bit value instead of 16
			val |= 0x3000; // prepend D/A command header (%0011xxxx)
			// put the data into a media block, big-endian
			fputc((val >> 8) & 0xFF, output_file);
			fputc((val     ) & 0xFF, output_file);
			media_pos += 2;
			length += 2;
		}
	}
	fclose(f);
	// pad the media block
	while (media_pos % 512) {
		// push on "dead air" (header + median value)
	  fputc(0x38, output_file);
	  fputc(0x00, output_file);
	  media_pos += 2;
	  length += 2;
	}

	return length;
}

void construct_events()
{
	unsigned long s, start_block;
	event_entry *e;
	
	// first event is the alarm. It's special.
	directory_pos = 0; // start of block 0, which is where events live.

	printf("Constructing alarm event from %s\n", alarm_song);
	// add the directory entry for the alarm
	start_block = media_pos / 512;
	directory[directory_pos++] = (start_block >> 24) & 0xFF;
	directory[directory_pos++] = (start_block >> 16) & 0xFF;
	directory[directory_pos++] = (start_block >>  8) & 0xFF;
	directory[directory_pos++] = (start_block      ) & 0xFF;
	s = add_clip(alarm_song, alarm_volume);
	start_block = media_pos / 512;
	directory[directory_pos++] = (start_block >> 24) & 0xFF;
	directory[directory_pos++] = (start_block >> 16) & 0xFF;
	directory[directory_pos++] = (start_block >>  8) & 0xFF;
	directory[directory_pos++] = (start_block      ) & 0xFF;
	
	// add directory entries for all of the "real" events. These take a 
	// filename in the struct, but they use that to determine the media 
	// id in the media queue.
	e = events;
	while (e && e->filename) {
	  if (e->year == 0xFF) {
	    if (e->bitpattern) {
	      printf("Processing event id %.2X/%.2X for %d/%d every year from %s\n",
		     e->id, e->bitpattern,
		     e->month, e->day, 
		     e->filename);
	    } else {
	      printf("Processing transient event %.2X for %d/%d every year from %s\n",
		     e->id,
		     e->month, e->day, 
		     e->filename );
	    }
	  } else {
	    if (e->bitpattern) {
	      printf("Processing event id %.2X/%.2X for %d/%d/%d from %s\n",
		     e->id, e->bitpattern,
		     e->month, e->day, 2000+e->year+yearfuzz,
		     e->filename);
	    } else {
	      printf("Processing transient event id %.2X for %d/%d/%d from %s\n",
		     e->id,
		     e->month, e->day, 2000+e->year,
		     e->filename);
	    }
	  }
		// 2 bytes of ID
		directory[directory_pos++] = e->id;
		directory[directory_pos++] = e->bitpattern;
		
		// year, month, day in BCD.
		if (e->year == 0xFF) 
		  directory[directory_pos++] = e->year;
		else
		  directory[directory_pos++] = to_bcd(e->year+yearfuzz);
		directory[directory_pos++] = to_bcd(e->month);
		directory[directory_pos++] = to_bcd(e->day);

		// media id.
		directory[directory_pos++] = media_id(e->filename);
		
		e++;
	}

	// 6 bytes per event.  8 bytes eaten up by alarm header.
	int num_events = ( ((3 * 512) - 8) / 6 );

	if (directory_pos >= 3*512) {
	  // Room for 3 pages of events (0-2), minus 8 bytes of alarm 
	  // header information, divided by the size of one event in 
	  // the directory (13 bytes).
	  fprintf(stderr, "ERROR: event directory is too long (room for %d events + 1 alarm).\n", num_events);
	  exit(-2);
	}

	printf("event directory has room for %d events + 1 alarm.\n", num_events);
}

void construct_media()
{
	char *p;
	int idx = 0;
	unsigned long s;
	unsigned long start_block;
	
	// Page 3 of directory: media files for time setting.
	directory_pos = 3*512;

	p = media[idx++];
	while (p) {
	  printf("Processing media file %s\n", p);
		start_block = media_pos / 512;
		directory[directory_pos++] = (start_block >> 24) & 0xFF;
		directory[directory_pos++] = (start_block >> 16) & 0xFF;
		directory[directory_pos++] = (start_block >>  8) & 0xFF;
		directory[directory_pos++] = (start_block      ) & 0xFF;
		s = add_clip(p, 0);
		printf(" -- clip is %lu bytes long\n", s);
		start_block = media_pos / 512;
		directory[directory_pos++] = (start_block >> 24) & 0xFF;
		directory[directory_pos++] = (start_block >> 16) & 0xFF;
		directory[directory_pos++] = (start_block >>  8) & 0xFF;
		directory[directory_pos++] = (start_block      ) & 0xFF;
	
		p = media[idx++];
	}

	if (1) {
	  int num_events = ( ((10-3) * 512) / 8 );
	  printf("Added %d pieces of media (room for %d; can only address 256 in code though).\n", idx-1, num_events);
	}

	if (directory_pos >= 10*512) {
	  fprintf(stderr, "ERROR: media directory is too long.\n");
	  exit(-3);
	}
}

void construct_firmware()
{
	FILE *f;
	unsigned long length = 0;
	unsigned char buf[512];
	unsigned long i;
	unsigned char crc7;

	// Page #10 (the 11th) of directory: firmware upgrade.
	directory_pos = 10*512;
	
	printf("Processing firmware version 0x%.2X from %s\n", firmware_version, firmware_image);
	
	f = fopen(firmware_image, "r");
	if (!f) {
	  fprintf(stderr, "Unable to open firmware image: %d\n", errno);
	  exit(-1);
	}

	directory_pos += 3; // skip 3 bytes for version#, size
	crc7 = crc7_file(f);
	printf("checksum: 0x%.2X\n", crc7);
	directory[directory_pos++] = crc7;
	fseek(f, 0, SEEK_SET);

	while (1) {
		size_t s = fread(buf, 1, 512, f);
		if (!s)
			break;
		for (i=0; i<s; i+=2) {
			unsigned short val = (buf[i] << 8) + buf[i+1];
			// put the data into a directory, little-endian
			directory[directory_pos++] = (val     ) & 0xFF;
			directory[directory_pos++] = (val >> 8) & 0xFF;
			length += 2;
		}
	}
	fclose(f);

	directory_pos = 10*512; // rewind...
	directory[directory_pos++] = firmware_version;
	length = 0x1e00 * 2; // FIXME: hack, trying to figure out what's up with firmware problems
	length /= 2; // need length in *words*, not *bytes*
	directory[directory_pos++] = (length >> 8) & 0xFF;
	directory[directory_pos++] = (length     ) & 0xFF;
}

void write_directory()
{
	fseek(output_file, 0, SEEK_SET);
	fwrite(directory, sizeof(directory), 1, output_file);
}

int main(int argc, char *argv[])
{
	memset(directory, 0, sizeof(directory));

	firmware_version = system("./version.pl")>>8;
	output_file = fopen("output2.img", "w");
	if (!output_file) {
		fprintf(stderr, "Unable to open output image: %d", errno);
		exit(-1);
	}
	
	construct_events();
	construct_media();
	construct_firmware();
	
	write_directory();
	
	fclose(output_file);
	
	return 0;
}
