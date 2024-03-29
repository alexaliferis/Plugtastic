/* 
 *	Plugtastic 
 *	
 *	Copyright © 2010 by Timothy Place
 *	All Rights Reserved
 */

#ifndef __PLUGTASTIC_INPUT_H__
#define __PLUGTASTIC_INPUT_H__

#include "TTDSP.h"


/**	TTGain is an exceptionally simple audio processor scales an input audio signal */
class PlugtasticInput : public TTAudioObject {
	TTCLASS_SETUP(PlugtasticInput)
	
	TTBoolean	mSidechain; ///< attr
	
	/**	A standard audio processing method as used by TTBlue objects.*/
	TTErr processAudio(TTAudioSignalArrayPtr inputs, TTAudioSignalArrayPtr outputs);
};


#endif // __PLUGTASTIC_INPUT_H__
