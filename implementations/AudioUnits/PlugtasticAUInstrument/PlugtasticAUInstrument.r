#include <AudioUnit/AudioUnit.r>

#include "PlugtasticAUInstrumentVersion.h"

// Note that resource IDs must be spaced 2 apart for the 'STR ' name and description
#define kAudioUnitResID_PlugtasticAUInstrument				1000

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ PlugtasticAUInstrument~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#define RES_ID			kAudioUnitResID_PlugtasticAUInstrument
#define COMP_TYPE		kAudioUnitType_MusicDevice
#define COMP_SUBTYPE	PlugtasticAUInstrument_COMP_SUBTYPE
#define COMP_MANUF		PlugtasticAUInstrument_COMP_MANF	

#define VERSION			kPlugtasticAUInstrumentVersion
#define NAME			"__MyCompanyName__: PlugtasticAUInstrument"
#define DESCRIPTION		"PlugtasticAUInstrument AU"
#define ENTRY_POINT		"PlugtasticAUInstrumentEntry"

#include "AUResources.r"
