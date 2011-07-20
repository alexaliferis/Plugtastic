#import <Cocoa/Cocoa.h>
#include <iostream>
#include "plug.out.h"
#include "TTAudioGraphDescription.h"
#include "PlugtasticParameter.h"


class PlugtasticAudioGraphDescription;
typedef std::vector<PlugtasticAudioGraphDescription>		PlugtasticAudioGraphDescriptionVector;
typedef PlugtasticAudioGraphDescriptionVector::iterator		PlugtasticAudioGraphDescriptionIter;


// for now, we only support a single main source and a single sidechain source
static TTString sourceObjectName = "";
static TTString sidechainSourceObjectName = "";

// we need to cache all of the parameters
class PlugtasticParameterNode {
public:
	TTObjectPtr mObject;
	TTString	mName;
};
typedef std::vector<PlugtasticParameterNode>		PlugtasticParameterNodeVector;
typedef PlugtasticParameterNodeVector::iterator		PlugtasticParameterNodeIter;

static PlugtasticParameterNodeVector*	sParameterNodes = NULL;


// Here was have a vector of bools to indicate whether or not we have generated the code for instantiating object with a given index
typedef std::vector<TTBoolean>			PlugtasticBoolVector;
typedef PlugtasticBoolVector::iterator	PlugtasticBoolIter;
static PlugtasticBoolVector*	sObjectCreated = NULL;


class PlugtasticGraphDescription : public TTGraphDescription {
public:
	int ExportNode(TTString& content, TTInt32& index, TTStringVector& nodeNames)
	{
		char	objName[16];
		TTValue	v;
		
		if (!mClassName)	// This should never be the case...
			return index;

		if (mUserData) {
			strncpy(objName, (const char*)mUserData, 16);
		}
		else {
			if (mUserData) {
				strncpy(objName, (const char*)mUserData, 16);
			}
			else {
				snprintf(objName, 16, "obj%u", (unsigned int)mID);
				
				mUserData = new char[16];
				strncpy((char*)mUserData, objName, 16);
				
				// can't push back because the ID numbers may have gaps
				//nodeNames.push_back(TTString(objName));			
				if (nodeNames.size() < mID+1)
					nodeNames.resize(mID+1);
				nodeNames[mID] = objName;
				
				if (sObjectCreated->size() < mID+1) {
					sObjectCreated->resize(mID+1);
					(*sObjectCreated)[mID] = false;
				}
				if (!(*sObjectCreated)[mID]) {
					(*sObjectCreated)[mID] = true;
					
					content += "\n";
					content += "		TTObjectInstantiate(TT(\"graph.object\"), (TTObjectPtr*)&";
					content += objName;
					content += ", TTValue(TT(\"";
					content += mClassName->getString();
					content += "\")));\n";
					
					if (mClassName == TT("plugtastic.parameter")) {
						PlugtasticParameterNode	parameterNode;
						
						parameterNode.mObject = mObjectInstance;
						parameterNode.mName = objName;
						sParameterNodes->push_back(parameterNode);
						
						content += "		((PlugtasticParameter*)";
						content += objName;
						content += "->mKernel)->setOwner(";
						content += objName;
						content += ");\n";
					}
					
					mObjectInstance->getAttributeNames(v);
					for (int i=0; i < v.getSize(); i++) {
						TTSymbolPtr attributeName;
						TTValue		attributeValue;
						TTString	attributeValueString;
						TTErr		err;
						
						v.get(i, &attributeName);
						err = mObjectInstance->getAttributeValue(attributeName, attributeValue);
						if (!err) {
							content += "		";
							content += objName;
							content += "->mKernel->setAttributeValue(TT(\"";
							content += attributeName->getString();
							content += "\"), ";
							if (attributeValue.getType() == kTypeSymbol) {
								TTSymbolPtr	attributeValueSymbol;
								
								attributeValue.get(0, &attributeValueSymbol);
								attributeValueString = "TT(\"";
								attributeValueString += attributeValueSymbol->getString();
								attributeValueString += "\")";
							}
							else if (attributeValue.getSize() > 1) {
								TTString temp;
								
								attributeValueString = "TTValue(";
								attributeValue.toString();
								attributeValue.get(0, temp);
								attributeValueString += temp;
								attributeValueString += ")";
							}
							else {
								attributeValue.toString();
								attributeValue.get(0, attributeValueString);
							}
							content += attributeValueString;
							content += ");\n";
						}
					}
					content += "\n";
				}
			}
		}
			
		for (TTGraphDescriptionIter input = mInputDescriptions.begin(); input != mInputDescriptions.end(); input++) {
			TTGraphDescription&	desc = *input;
			int					inputIndex = ((PlugtasticGraphDescription&)desc).ExportNode(content, mID, nodeNames); // note: calls into TTGraph's exportCppNode

			content += "	";
			content += objName;
			content += "->connect(";
			content += nodeNames[inputIndex];
			content += ");\n";
		}	
		return mID;
	}
	
};


class PlugtasticAudioGraphDescription : public TTAudioGraphDescription {
public:
	int ExportNode(TTString& content, TTInt32& index, TTStringVector& nodeNames)
	{
		char	objName[16];
		bool	isPlugtasticInput = false;
		TTValue	v;
		char	str[16];
		
		if (!mClassName)	// This should never be the case...
			return index;
				
		if (mClassName == TT("plugtastic.input"))
			isPlugtasticInput = true;
		
		if (mUserData) {
			strncpy(objName, (const char*)mUserData, 16);
		}
		else {
			snprintf(objName, 16, "obj%u", (unsigned int)mID);
			
			mUserData = new char[16];
			strncpy((char*)mUserData, objName, 16);
			
			// can't push back because the ID numbers may have gaps
			//nodeNames.push_back(TTString(objName));			
			if (nodeNames.size() < mID+1)
				nodeNames.resize(mID+1);
			nodeNames[mID] = objName;
						
			if (!sObjectCreated)
				sObjectCreated = new PlugtasticBoolVector;
			if (sObjectCreated->size() < mID+1) {
				sObjectCreated->resize(mID+1);
				(*sObjectCreated)[mID] = false;
			}
			if (!(*sObjectCreated)[mID]) {
				(*sObjectCreated)[mID] = true;
				
				content += "		audioObjectArguments.set(0, TT(\"";
				if (isPlugtasticInput)
					content += "audio.generator";
				else
					content += mClassName->getString();
				content += "\"));\n";

				content += "		audioObjectArguments.set(1, ";
				snprintf(str, 16, "%u", (unsigned int)mNumInlets);
				content += str;
				content += ");\n"; // number of inlets
				content += "		audioObjectArguments.set(2, ";
				snprintf(str, 16, "%u", (unsigned int)mNumOutlets);
				content += str;
				content += ");\n"; // number of outlets
				
				content += "		TTObjectInstantiate(TT(\"audio.object\"), (TTObjectPtr*)&";
				content += objName;
				content += ", audioObjectArguments);\n";
				
				if (isPlugtasticInput) {
					content += "		";
					content += objName;
					content += "->addAudioFlag(kTTAudioGraphGenerator);\n";
					
					
					TTBoolean isSidechain = NO;

					mObjectInstance->getAttributeValue(TT("sidechain"), isSidechain);
					if (isSidechain) {
						sidechainSourceObjectName = objName;
					}
					else {
						// cache the name of the input -- we'll want to know it down in the process() method
						sourceObjectName = objName;
					}
				}
				
				mObjectInstance->getAttributeNames(v);
				for (int i=0; i < v.getSize(); i++) {
					TTSymbolPtr attributeName;
					TTValue		attributeValue;
					TTString	attributeValueString;
					TTErr		err;
					TTBoolean	isArray = NO;
					
					v.get(i, &attributeName);
					err = mObjectInstance->getAttributeValue(attributeName, attributeValue);
					if (!err) {						
						if (attributeValue.getSize() > 1) {
							TTString temp;
							
							content += "		TTValue v(";
							attributeValue.toString();
							attributeValue.get(0, temp);
//							temp.resize(temp.size()-1);
							for (int c=0; c<temp.size(); c++) {
								if (temp[c] == ' ')
									temp[c] = ',';
							}
							content += temp;
							content += ");\n";
							isArray = YES;
						}
						
						content += "		";
						content += objName;
						content += "->mKernel->setAttributeValue(TT(\"";
						content += attributeName->getString();
						content += "\"), ";
						if (isArray)
							attributeValueString = "v";
						else if (attributeValue.getType() == kTypeSymbol) {
							TTSymbolPtr	attributeValueSymbol;
							
							attributeValue.get(0, &attributeValueSymbol);
							attributeValueString = "TT(\"";
							attributeValueString += attributeValueSymbol->getString();
							attributeValueString += "\")";
						}
						else {
							attributeValue.toString();
							attributeValue.get(0, attributeValueString);
							if (attributeValueString == "-inf ") {
								attributeValueString = "-INFINITY";
							}
						}
						
						content += attributeValueString;
						content += ");\n";
					}
				}
				content += "\n";
			}
		}
		
		if (!isPlugtasticInput) { // <-- ignore anything feeding the input from the patcher (output is ignored by virtual of starting at plug.out≈
			int inletNum = 0;
			
			for (TTAudioGraphDescriptionVectorsIter inlet = mAudioDescriptionsForInlets.begin(); inlet != mAudioDescriptionsForInlets.end(); inlet++) {
				for (TTAudioGraphDescriptionIter input = inlet->begin(); input != inlet->end(); input++) {
					TTAudioGraphDescription&	desc = *input;
					int							inputIndex = ((PlugtasticAudioGraphDescription&)desc).ExportNode(content, mID, nodeNames);
					char						str[16];
					
					content += "		";
					content += objName;
					content += "->connectAudio(";
					content += nodeNames[inputIndex];
					content += ", ";
					snprintf(str, 16, "%u", (unsigned int)desc.mOutletNumber);
					content += str;	// fromOutletNumber
					content += ", ";
					snprintf(str, 16, "%i", inletNum);
					content += str;		// toInletNumber
					content += ");\n";
				}
				for (TTGraphDescriptionIter input = mControlDescription.mInputDescriptions.begin(); input != mControlDescription.mInputDescriptions.end(); input++) {
					TTGraphDescription&		desc = *input;
					int						inputIndex = ((PlugtasticGraphDescription&)desc).ExportNode(content, mID, nodeNames);
					
					content += "		";
					content += objName;
					content += "->connect(";
					content += nodeNames[inputIndex];
					content += ");\n";
				}
				
				inletNum++;
			}
			
		}
		return mID;
	}
};


void PlugOutPostError(PlugOutPtr self)
{
	object_error_obtrusive(SELF, "Plugtastic cannot build plug-in.  See Max window for details.");
	object_error(SELF, "Xcode is not installed on this system!");
	object_error(SELF, "Plugtastic requires that you install Apple's free Developer Tools");
	object_error(SELF, "Please download from Apple @ http://developer.apple.com");	
}


void PlugOutPostFail(PlugOutPtr self)
{
	object_error_obtrusive(SELF, "Plugtastic plug-in compilation failed. See Max window for details.");
	object_error(SELF, "There were errors from Xcode when compiling this plug-in.");
	object_error(SELF, "A log file with information about these errors is located at ~/Library/Logs/Plugtastic.log");
}


void PlugOutPostSuccess(PlugOutPtr self)
{
	object_post(SELF, "Plugtastic plug-in compilation successful.  Plug-in located at ~/Library/Audio/Plug-Ins/Components");
}


void PlugOutDoBuildAudioUnit_Export(PlugOutPtr self)
{
	NSFileManager*		fileManager = [NSFileManager defaultManager];
	NSMutableString*	tempPath = [[NSMutableString alloc] initWithString:NSTemporaryDirectory()];
	NSBundle*			plugoutBundle = [NSBundle bundleWithIdentifier:@"org.jamoma.plug.out≈"];
	NSString*			plugoutBundlePath = [plugoutBundle bundlePath];
	NSMutableString*	plugtasticTemplatePath = [[NSMutableString alloc] initWithString:plugoutBundlePath];
	NSError*			err = nil;
	std::string			filecontents = "";
	std::string			filepath = [tempPath UTF8String];
	FILE				*file;
	char				str[16];
	std::string			xcode_log = "";
	bool				isInstrument = NO;
	
	sourceObjectName = "";
	sidechainSourceObjectName = "";
	
	// 0. Parse the graph
	
	PlugtasticAudioGraphDescription	desc;
	TTString						content;
	TTInt32							index = -1;
	TTStringVector					nodeNames;
	
	if (!sParameterNodes)
		sParameterNodes = new PlugtasticParameterNodeVector;
	else
		sParameterNodes->clear();
	
	if (!sObjectCreated)
		sObjectCreated = new PlugtasticBoolVector;
	else
		sObjectCreated->clear();
	
	self->audioGraphObject->prepareAudioDescription();
	self->audioGraphObject->getAudioDescription(desc);
	desc.ExportNode(content, index, nodeNames);
	
	nodeNames.clear();
	for (int i=0; i<desc.sIndex; i++) {
		TTString nodeName = "obj";
		
		snprintf(str, 16, "%i", i);
		nodeName += str;
		nodeNames.push_back(nodeName);
	}
	
	if (sourceObjectName == "")
		isInstrument = YES;
	
	
	// 1. Create and Copy Template Xcode Project
	
	[tempPath appendString:@"PlugtasticAU"];
	[fileManager removeFileAtPath:tempPath handler:nil];
	[fileManager createDirectoryAtPath:tempPath withIntermediateDirectories:TRUE attributes:nil error:&err];

	if (isInstrument) {
		[plugtasticTemplatePath appendString:@"/Contents/Resources/PlugtasticAUInstrument"];
		[tempPath appendString:@"/PlugtasticAUInstrument"];
	}
	else {
		[plugtasticTemplatePath appendString:@"/Contents/Resources/PlugtasticAUEffect"];
		[tempPath appendString:@"/PlugtasticAUEffect"];
	}
	[fileManager copyItemAtPath:plugtasticTemplatePath toPath:tempPath error:&err];
	
	
	// 2. generate PlugtasticAUEffect.xcconfig in the temp location
	
	filecontents = "";
	filepath = [tempPath UTF8String];
	
	if (isInstrument)
		filepath += "/PlugtasticAUInstrument.xcconfig";
	else
		filepath += "/PlugtasticAUEffect.xcconfig";
	
	filecontents += "PRODUCT_NAME = ";
	filecontents += self->pluginName->s_name;
	filecontents += "\n";
	
	filecontents += "PRODUCT_VERSION = ";
	filecontents += self->pluginVersion->s_name;
	filecontents += "\n";
	
	filecontents += "MANUFACTURER_NAME = ";
	filecontents += self->pluginManufacturer->s_name;
	filecontents += "\n";
	
	filecontents += "DSTROOT = /\n";
	filecontents += "DEPLOYMENT_LOCATION = YES\n";
	filecontents += "\n";
	
	
	file = fopen(filepath.c_str(), "w");
	if (file) {
		fwrite(filecontents.c_str(), sizeof(char), filecontents.size(), file);
		fclose(file);
	}
	
	
	// 5. generate PlugtasticAUEffectGraph.h  ( *** This is the big dog *** )	 

	filecontents = "";
	filepath = [tempPath UTF8String];
	
	if (isInstrument)
		filepath += "/PlugtasticAUInstrumentGraph.h";
	else
		filepath += "/PlugtasticAUEffectGraph.h";
	
	filecontents += "#ifndef __PlugtasticAUGraph_h__\n";
	filecontents += "#define __PlugtasticAUGraph_h__\n";
	filecontents += "\n";
	filecontents += "#include \"PlugtasticAPI.h\"\n";
	filecontents += "#include \"AUEffectBase.h\"\n";
	filecontents += "#include \"PlugtasticParameter.h\"";
	filecontents += "\n";
	filecontents += "\n";
	
	// 5a. first we implement the graph
	
	if (isInstrument)
		filecontents += "class PlugtasticAUInstrumentGraph {\n";
	else
		filecontents += "class PlugtasticAUEffectGraph {\n";
	filecontents += "	friend class PlugtasticAUParameters;\n\n";
	filecontents += "	TTAudioGraphPreprocessData	mInitData;\n";
	filecontents += "	TTAudioSignalPtr			mAudioSignal;\n";
		
	for (TTStringIter name = nodeNames.begin(); name != nodeNames.end(); name++) {
		filecontents += "	TTAudioGraphObjectPtr		";
		filecontents += (*name).c_str();
		filecontents += ";\n";
	}
	
	filecontents += "\n";
	filecontents += "public:\n";
	filecontents += "	uint			mVectorSize;\n";
	filecontents += "\n";
	
	if (isInstrument)
		filecontents += "	PlugtasticAUInstrumentGraph() : \n";
	else
		filecontents += "	PlugtasticAUEffectGraph() : \n";

	for (TTStringIter name = nodeNames.begin(); name != nodeNames.end(); name++) {
		filecontents += "		";
		filecontents += (*name).c_str();
		filecontents += "(NULL),\n";
	}
	filecontents += "		mAudioSignal(NULL)\n";
	filecontents += "	{\n";
	filecontents += "		TTValue audioObjectArguments;\n";
	filecontents += "\n";
	filecontents += "		audioObjectArguments.setSize(3);\n";
	filecontents += "		PlugtasticInit(\"/Library/Application Support/Plugtastic\");\n";
	filecontents += "	\n";
	filecontents += content;	
	filecontents += "	}\n";
	
	filecontents += "\n\n";

	if (isInstrument)
		filecontents += "	virtual ~PlugtasticAUInstrumentGraph()\n";
	else
		filecontents += "	virtual ~PlugtasticAUEffectGraph()\n";

	filecontents += "	{\n";
	for (TTStringIter name = nodeNames.begin(); name != nodeNames.end(); name++) {
		filecontents += "		TTObjectRelease((TTObjectPtr*)&";
		filecontents += (*name).c_str();
		filecontents += ");\n";
	}
	filecontents += "	}\n";
	
	// process method follows
	// obj0 is always the sink
	// the source could be anything though...
	// for now, we limit ourselves to one source, whose name we cache when we go through the desc nodes.
	
	filecontents += "	\n\n";
	filecontents += "	void process(const AudioBufferList* inBufferList, AudioBufferList* outBufferList, const AudioBufferList* sidechainInBufferList, AudioBufferList* sidechainOutBufferList)\n";
	filecontents += "	{\n";
	filecontents += "		TTUInt16 channel;\n";
	filecontents += "		TTUInt16 inChannelCount = inBufferList->mNumberBuffers;\n";
	filecontents += "		TTUInt32 outChannelCount = outBufferList->mNumberBuffers;\n";
	if (sidechainSourceObjectName.length() > 0) {
		filecontents += "		TTUInt16 sidechainInChannelCount = sidechainInBufferList->mNumberBuffers;\n";
	}	
	filecontents += "		\n";
	filecontents += "		// copy the input\n";
	
	filecontents += "		";
	filecontents += sourceObjectName;
	filecontents += "->getUnitGenerator()->setAttributeValue(TT(\"vectorSize\"), mVectorSize);\n";
	filecontents += "		";
	filecontents += sourceObjectName;
	filecontents += "->getUnitGenerator()->setAttributeValue(TT(\"maxNumChannels\"), inChannelCount);\n";
	filecontents += "		";
	filecontents += sourceObjectName;
	filecontents += "->getUnitGenerator()->setAttributeValue(TT(\"numChannels\"), inChannelCount);\n";
	filecontents += "		";
	filecontents += sourceObjectName;
	filecontents += "->setOutputNumChannels(0, inChannelCount);\n";

	if (sidechainSourceObjectName.length() > 0) {
		filecontents += "		";
		filecontents += sidechainSourceObjectName;
		filecontents += "->getUnitGenerator()->setAttributeValue(TT(\"vectorSize\"), mVectorSize);\n";
		filecontents += "		";
		filecontents += sidechainSourceObjectName;
		filecontents += "->getUnitGenerator()->setAttributeValue(TT(\"maxNumChannels\"), sidechainInChannelCount);\n";
		filecontents += "		";
		filecontents += sidechainSourceObjectName;
		filecontents += "->getUnitGenerator()->setAttributeValue(TT(\"numChannels\"), sidechainInChannelCount);\n";
		filecontents += "		";
		filecontents += sidechainSourceObjectName;
		filecontents += "->setOutputNumChannels(0, sidechainInChannelCount);\n";
	}	
	
	filecontents += "		\n";
	filecontents += "		// TODO: All of this channel-related stuff can be set once at setup -- it doesn't need to be called every vector!\n";
	filecontents += "		\n";
	filecontents += "		for (channel=0; channel != inChannelCount; channel++)\n";

	filecontents += "			TTAudioGraphGeneratorPtr(";
	filecontents += sourceObjectName;
	filecontents += "->getUnitGenerator())->mBuffer->setVector(channel, mVectorSize, (TTFloat32*)inBufferList->mBuffers[channel].mData);\n";
	
	if (sidechainSourceObjectName.length() > 0) {	
		filecontents += "		for (channel=0; channel != sidechainInChannelCount; channel++)\n";
		filecontents += "			TTAudioGraphGeneratorPtr(";
		filecontents += sidechainSourceObjectName;
		filecontents += "->getUnitGenerator())->mBuffer->setVector(channel, mVectorSize, (TTFloat32*)sidechainInBufferList->mBuffers[channel].mData);\n";
	}
	
	filecontents += "		\n";
	filecontents += "		// run the graph\n";
	filecontents += "		mInitData.vectorSize = mVectorSize;\n";
	filecontents += "		\n";
	filecontents += "		obj0->lockProcessing();\n";
	filecontents += "		obj0->preprocess(mInitData);\n";
	filecontents += "		obj0->process(mAudioSignal);\n";
	filecontents += "		obj0->unlockProcessing();\n";
	filecontents += "		\n";
	filecontents += "		// copy the output\n";
	filecontents += "		for (channel=0; channel != outChannelCount; channel++)\n";
	filecontents += "			mAudioSignal->getVector(channel, mVectorSize, (TTFloat32*)outBufferList->mBuffers[channel].mData);\n";
	filecontents += "	}\n";
	filecontents += "};\n";
	filecontents += "\n";
	filecontents += "\n";

	// 5b. now we can setup parameter info
	
	for (PlugtasticParameterNodeIter parameter = sParameterNodes->begin(); parameter != sParameterNodes->end(); parameter++) {
		filecontents += "float kDefaultValue_";
		filecontents += parameter->mName;
		filecontents += " = ";
		
		snprintf(str, 16, "%f", PlugtasticParameterPtr(parameter->mObject)->mDefault);
		filecontents += str;
		filecontents += ";\n";
	}
	filecontents += "\n";
		
	for (PlugtasticParameterNodeIter parameter = sParameterNodes->begin(); parameter != sParameterNodes->end(); parameter++) {
		filecontents += "CFStringRef kParameter";
		filecontents += parameter->mName;
		filecontents += "Name = CFSTR(\"";
		filecontents += PlugtasticParameterPtr(parameter->mObject)->mName->getCString();
		filecontents += "\");\n";
	}
	filecontents += "\n";
	
	filecontents += "enum {\n";
	int j = 0;
	for (PlugtasticParameterNodeIter parameter = sParameterNodes->begin(); parameter != sParameterNodes->end(); parameter++) {
		filecontents += "	kParam_";
		filecontents += parameter->mName;
		filecontents += " = ";

		snprintf(str, 16, "%i", j);
		filecontents += str;
		filecontents += ",\n";
		j++;
	}
	filecontents += "	kNumberOfParameters = ";

	snprintf(str, 16, "%i", j);
	filecontents += str;
	filecontents += "\n};\n\n";

	if (isInstrument)
		filecontents += "#include \"PlugtasticAUInstrument.h\"\n\n";
	else
		filecontents += "#include \"PlugtasticAUEffect.h\"\n\n";

	filecontents += "class PlugtasticAUParameters {\n";
	
	filecontents += "	// we copy this function from the AUBase file, because that file declares this method as a protected member for some reason\n";
	filecontents += "	static void FillInParameterName (AudioUnitParameterInfo& ioInfo, CFStringRef inName, bool inShouldRelease)\n";
	filecontents += "	{\n";
	filecontents += "		ioInfo.cfNameString = inName;\n";
	filecontents += "		ioInfo.flags |= kAudioUnitParameterFlag_HasCFNameString;\n";
	filecontents += "		if (inShouldRelease)\n";
	filecontents += "			ioInfo.flags |= kAudioUnitParameterFlag_CFNameRelease;\n";
	filecontents += "		CFStringGetCString(inName, ioInfo.name, offsetof (AudioUnitParameterInfo, clumpID), kCFStringEncodingUTF8);\n";
	filecontents += "	}\n";
	filecontents += "\n\n";	
	
	filecontents += "public:\n";
	filecontents += "	OSStatus getInfo(AudioUnitScope inScope, AudioUnitParameterID inParameterID, AudioUnitParameterInfo &outParameterInfo)\n";
	filecontents += "	{\n";
	filecontents += "		OSStatus result = noErr;\n";
	filecontents += "\n";
	filecontents += "		outParameterInfo.flags = kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable;\n";
	filecontents += "\n";
	filecontents += "	    if (inScope == kAudioUnitScope_Global) {\n";
	filecontents += "	        switch (inParameterID) {\n";
	
	for (PlugtasticParameterNodeIter parameter = sParameterNodes->begin(); parameter != sParameterNodes->end(); parameter++) {	
		filecontents += "	            case kParam_";
		filecontents += parameter->mName;
		filecontents += ":\n";
		
		filecontents += "	                FillInParameterName(outParameterInfo, kParameter";
		filecontents += parameter->mName;
		filecontents += "Name, false);\n";
		
		// TODO: implement these styles, maybe using the DataspaceLib?
		if (PlugtasticParameterPtr(parameter->mObject)->mStyle == TT("boolean"))
			filecontents += "	                outParameterInfo.unit = kAudioUnitParameterUnit_Boolean;\n";
		else if (PlugtasticParameterPtr(parameter->mObject)->mStyle == TT("hertz"))
			filecontents += "	                outParameterInfo.unit = kAudioUnitParameterUnit_Hertz;\n";
		else if (PlugtasticParameterPtr(parameter->mObject)->mStyle == TT("decibels"))
			filecontents += "	                outParameterInfo.unit = kAudioUnitParameterUnit_Decibels;\n";
		else if (PlugtasticParameterPtr(parameter->mObject)->mStyle == TT("milliseconds"))
			filecontents += "	                outParameterInfo.unit = kAudioUnitParameterUnit_Milliseconds;\n";
		else
			filecontents += "	                outParameterInfo.unit = kAudioUnitParameterUnit_Generic;\n";
		
		filecontents += "	                outParameterInfo.minValue = ";
		snprintf(str, 16, "%f", PlugtasticParameterPtr(parameter->mObject)->mRangeBottom);
		filecontents += str;
		filecontents += ";\n";
		
		filecontents += "	                outParameterInfo.maxValue = ";
		snprintf(str, 16, "%f", PlugtasticParameterPtr(parameter->mObject)->mRangeTop);
		filecontents += str;
		filecontents += ";\n";
		
		filecontents += "	                outParameterInfo.defaultValue = kDefaultValue_";
		filecontents += parameter->mName;
		filecontents += ";\n";
		filecontents += "	                break;\n";
	}
	
	filecontents += "	            default:\n";
	filecontents += "	                result = kAudioUnitErr_InvalidParameter;\n";
	filecontents += "	                break;\n";
	filecontents += "			}\n";
	filecontents += "		}\n";
	filecontents += "		else\n";
	filecontents += "	        result = kAudioUnitErr_InvalidParameter;\n";
	filecontents += "\n";
	filecontents += "		return result;\n";
	filecontents += "	}\n";
	filecontents += "	\n\n";

	if (isInstrument)
		filecontents += "	void setDefaults(PlugtasticAUInstrument* self)\n";		
	else
		filecontents += "	void setDefaults(PlugtasticAUEffect* self)\n";
	filecontents += "	{\n";
	
	for (PlugtasticParameterNodeIter parameter = sParameterNodes->begin(); parameter != sParameterNodes->end(); parameter++) {
		filecontents += "		self->SetParameter(kParam_";
		filecontents += parameter->mName;
		filecontents += ", kDefaultValue_";
		filecontents += parameter->mName;
		filecontents += ");\n";
	}
	
	filecontents += "	}\n";
	filecontents += "	\n\n";

	
	if (isInstrument)
		filecontents += "	void setParameter(PlugtasticAUInstrumentGraph* graph, AudioUnitParameterID inID, Float32 inValue)\n";		
	else
		filecontents += "	void setParameter(PlugtasticAUEffectGraph* graph, AudioUnitParameterID inID, Float32 inValue)\n";
	filecontents += "	{\n";
	filecontents += "		switch (inID) {\n";
	for (PlugtasticParameterNodeIter parameter = sParameterNodes->begin(); parameter != sParameterNodes->end(); parameter++) {
		filecontents += "			case kParam_";
		filecontents += parameter->mName;
		filecontents += ":\n";
		filecontents += "				graph->";
		filecontents += parameter->mName;
		filecontents += "->mKernel->setAttributeValue(TT(\"value\"), inValue);\n";
		filecontents += "				break;\n";
	}
	filecontents += "			default:\n";
	filecontents += "				break;\n";
	filecontents += "		}\n";	
	filecontents += "	}\n";
	
	
	filecontents += "};\n";
	filecontents += "\n";
	
	
	
	filecontents += "\n";
	filecontents += "#endif // __PlugtasticAUGraph_h__\n";
	
	file = fopen(filepath.c_str(), "w");
	if (file) {
		fwrite(filecontents.c_str(), sizeof(char), filecontents.size(), file);
		fclose(file);
	}
	
	
	// These next two actually have to come after the graph generation so we know about sidechains, etc.
	
	// 3. generate PlugtasticAUEffectVersion.h
	
	filecontents = "";
	filepath = [tempPath UTF8String];
	
	filepath += "/PlugtasticAUEffectVersion.h";
	
	filecontents += "#ifndef __PlugtasticAUEffectVersion_h__\n";
	filecontents += "#define __PlugtasticAUEffectVersion_h__\n";
	filecontents += "\n";
	
	filecontents += "#define kPlugtasticAUEffectVersion			";
	filecontents += self->pluginVersionHex->s_name;
	filecontents += "\n";
	
	filecontents += "#define PlugtasticAUEffect_COMP_SUBTYPE		'";
	filecontents += self->pluginID->s_name;
	filecontents += "'\n";
	
	filecontents += "#define PlugtasticAUEffect_COMP_MANF		'";
	filecontents += self->pluginManufacturerCode->s_name;
	filecontents += "'\n\n";
	
	if (sidechainSourceObjectName.length() > 0) {
		filecontents += "#define PlugtasticAUEffect_HasSidechainInput\n";
	}
	
	filecontents += "\n";
	filecontents += "#endif // __PlugtasticAUEffectVersion_h__\n";
	
	file = fopen(filepath.c_str(), "w");
	if (file) {
		fwrite(filecontents.c_str(), sizeof(char), filecontents.size(), file);
		fclose(file);
	}
	
	
	// 4. generate PlugtasticAUEffect.r
	
	filecontents = "";
	filepath = [tempPath UTF8String];
	
	filepath += "/PlugtasticAUEffect.r";
	
	filecontents += "#include <AudioUnit/AudioUnit.r>\n";
	filecontents += "#include \"PlugtasticAUEffectVersion.h\"\n";
	filecontents += "#define kAudioUnitResID_PlugtasticAUEffect 1000\n";
	filecontents += "\n";
	filecontents += "#define RES_ID			kAudioUnitResID_PlugtasticAUEffect\n";
	filecontents += "#define COMP_TYPE		kAudioUnitType_Effect\n";
	filecontents += "#define COMP_SUBTYPE	PlugtasticAUEffect_COMP_SUBTYPE\n";
	filecontents += "#define COMP_MANUF		PlugtasticAUEffect_COMP_MANF\n";
	filecontents += "\n";
	filecontents += "#define VERSION		kPlugtasticAUEffectVersion\n";
	
	filecontents += "#define NAME			\"";
	filecontents += self->pluginManufacturer->s_name;
	filecontents += ": ";
	filecontents += self->pluginName->s_name;
	filecontents += "\"\n";
	
	filecontents += "#define DESCRIPTION	\"";
	filecontents += self->pluginName->s_name;
	filecontents += " AU Plug-in\"\n";
	
	filecontents += "#define ENTRY_POINT		\"PlugtasticAUEffectEntry\"\n";
	filecontents += "\n";
	filecontents += "#include \"AUResources.r\"\n";
	
	file = fopen(filepath.c_str(), "w");
	if (file) {
		fwrite(filecontents.c_str(), sizeof(char), filecontents.size(), file);
		fclose(file);
	}
	
	
	
	// 6. Build the Xcode Project
	
	char		command[4096];
	char		xcode_output[4096];
	int			ret = 0;
	int			progress = 0;
	bool		xcode_check = false;
	
	// first we check to see if xcodebuild is installed -- if not we need to abort
	file = popen("which xcodebuild", "r");
	if (file) {
		while (fgets(xcode_output, 4096, file)) {
			if (xcode_output[0] != 0)
				xcode_check = true;
		}
		pclose(file);
	}
	else {
		cpost("Plugtastic: failed to check 'which xcodebuild\n");
	}

	if (xcode_check != true) {
		defer_low(self, (method)PlugOutPostError, NULL, 0, NULL);
		goto out;
	}
	
	// now we can actually get on with building the thing

	snprintf(command, 4096, "cd \"%s\"; xcodebuild clean; xcodebuild", [tempPath UTF8String]);
	file = popen(command, "r");
	if (file) {
		while (fgets(xcode_output, 4096, file)) {
			
			if (strstr(xcode_output, "** CLEAN SUCCEEDED **"))
				progress++;
			else if (strstr(xcode_output, "ProcessInfoPlistFile"))
				progress++;
			else if (strstr(xcode_output, "PlugtasticAUEffect.cpp normal x86_64 c++"))
				progress++;
			else if (strstr(xcode_output, "AudioUnits/AUPublic/AUBase/AUDispatch.cpp normal x86_64 c++"))
				progress++;
			else if (strstr(xcode_output, "AudioUnits/AUPublic/AUBase/AUInputElement.cpp normal x86_64 c++"))
				progress++;
			else if (strstr(xcode_output, "AudioUnits/AUPublic/AUBase/AUOutputElement.cpp normal x86_64 c++"))
				progress++;
			else if (strstr(xcode_output, "AUPublic/AUBase/AUBase.cpp normal x86_64 c++"))
				progress++;
			else if (strstr(xcode_output, "AudioUnits/AUPublic/AUBase/ComponentBase.cpp normal x86_64 c++"))
				progress++;
			else if (strstr(xcode_output, "AudioUnits/AUPublic/AUBase/AUScopeElement.cpp normal x86_64 c++"))
				progress++;
			else if (strstr(xcode_output, "AudioUnits/AUPublic/Utility/AUDebugDispatcher.cpp normal x86_64 c++"))
				progress++;
			else if (strstr(xcode_output, "AudioUnits/AUPublic/OtherBases/AUEffectBase.cpp normal x86_64 c++"))
				progress++;
			else if (strstr(xcode_output, "PublicUtility/CAMutex.cpp normal x86_64 c++"))
				progress++;
			else if (strstr(xcode_output, "PublicUtility/CAAudioChannelLayout.cpp normal x86_64 c++"))
				progress++;
			else if (strstr(xcode_output, "AUPublic/Utility/AUBuffer.cpp normal x86_64 c++"))
				progress++;
			else if (strstr(xcode_output, "PublicUtility/CAVectorUnit.cpp normal x86_64 c++"))
				progress++;
			else if (strstr(xcode_output, "PublicUtility/CAAUParameter.cpp normal x86_64 c++"))
				progress++;
			else if (strstr(xcode_output, "PlugtasticAUEffect.cpp normal i386 c++"))
				progress++;
			else if (strstr(xcode_output, "AudioUnits/AUPublic/AUBase/AUDispatch.cpp normal i386 c++"))
				progress++;
			else if (strstr(xcode_output, "AudioUnits/AUPublic/AUBase/AUInputElement.cpp normal i386 c++"))
				progress++;
			else if (strstr(xcode_output, "AudioUnits/AUPublic/AUBase/AUOutputElement.cpp normal i386 c++"))
				progress++;
			else if (strstr(xcode_output, "AUPublic/AUBase/AUBase.cpp normal i386 c++"))
				progress++;
			else if (strstr(xcode_output, "AudioUnits/AUPublic/AUBase/ComponentBase.cpp normal i386 c++"))
				progress++;
			else if (strstr(xcode_output, "AudioUnits/AUPublic/AUBase/AUScopeElement.cpp normal i386 c++"))
				progress++;
			else if (strstr(xcode_output, "AudioUnits/AUPublic/Utility/AUDebugDispatcher.cpp normal i386 c++"))
				progress++;
			else if (strstr(xcode_output, "AudioUnits/AUPublic/OtherBases/AUEffectBase.cpp normal i386 c++"))
				progress++;
			else if (strstr(xcode_output, "PublicUtility/CAMutex.cpp normal i386 c++"))
				progress++;
			else if (strstr(xcode_output, "PublicUtility/CAAudioChannelLayout.cpp normal i386 c++"))
				progress++;
			else if (strstr(xcode_output, "AUPublic/Utility/AUBuffer.cpp normal i386 c++"))
				progress++;
			else if (strstr(xcode_output, "PublicUtility/CAVectorUnit.cpp normal i386 c++"))
				progress++;
			else if (strstr(xcode_output, "PublicUtility/CAAUParameter.cpp normal i386 c++"))
				progress++;
			else if (strstr(xcode_output, "CoreAudio/PublicUtility/CAStreamBasicDescription.cpp"))
				progress++;
			else if (strstr(xcode_output, "AUPublic/AUBase/AUBase.cpp normal i386 c++"))
				progress++;
			else if (strstr(xcode_output, "AudioUnits/AUPublic/Utility/AUBaseHelper.cpp normal x86_64 c++"))
				progress++;
			else if (strstr(xcode_output, "Ld \"build/PlugtasticAUEffect.build/"))
				progress++;
			else if (strstr(xcode_output, "Ld build/PlugtasticAUEffect.build/"))
				progress++;
			else if (strstr(xcode_output, "/usr/bin/lipo -create "))
				progress++;
			else if (strstr(xcode_output, "Rez build/PlugtasticAUEffect.build"))
				progress++;
			else if (strstr(xcode_output, "ResMergerCollector "))
				progress++;
			else if (strstr(xcode_output, "ResMergerProduct "))
				progress++;
			else if (strstr(xcode_output, "/usr/bin/touch -c "))
				progress++;

			set_progress_window(self, progress * 2.56);
			//std::cout << xcode_output << std::endl << std::endl;
			xcode_log += xcode_output;
			xcode_log += "\n\n";
		}
		ret = pclose(file);
		
		
		// Create a Log
		// Should we encrypt this somehow?
		
		tempPath = [[NSMutableString alloc] initWithString:NSHomeDirectory()];
		filepath = [tempPath UTF8String];
		filepath += "/Library/Logs/Plugtastic.log";
		
		file = fopen(filepath.c_str(), "w");
		if (file) {
			fwrite(xcode_log.c_str(), sizeof(char), xcode_log.size(), file);
			fclose(file);
		}
		
		if (strstr(xcode_log.c_str(), ": error: "))
			defer_low(self, (method)PlugOutPostFail, NULL, 0, NULL);
		else
			defer_low(self, (method)PlugOutPostSuccess, NULL, 0, NULL);
	}

out:
	// 7. Cleanup?  Delete temp dir?
	
	
	// 8. All done!
	close_progress_window(self);
	self->buildThread = NULL;
}
