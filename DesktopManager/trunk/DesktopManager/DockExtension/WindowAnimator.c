/* DesktopManager -- A virtual desktop provider for OS X
*
* Copyright (C) 2003, 2004 Richard J Wareham <richwareham@users.sourceforge.net>
* This program is free software; you can redistribute it and/or modify it 
* under the terms of the GNU General Public License as published by the Free 
* Software Foundation; either version 2 of the License, or (at your option)
* any later version.
*
* This program is distributed in the hope that it will be useful, but 
* WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY 
* or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License 
* for more details.
*
* You should have received a copy of the GNU General Public License along 
* with this program; if not, write to the Free Software Foundation, Inc., 675 
* Mass Ave, Cambridge, MA 02139, USA.
*/

#include "WindowAnimator.h"
#include <stdlib.h>
#include <unistd.h>
#include <math.h>

#define MAX_ANIMATIONS 100

typedef struct {
	CGSWindow *pWidList;
	CGAffineTransform *pOrigTransforms;
	float *pOrigAlphas;
	int nWids;
	CGAffineTransform startTransform;
	CGAffineTransform endTransform;
	float startAlpha, endAlpha;
	int duration;
	float progress;
} _Animation;

_Animation* _animationList[MAX_ANIMATIONS];

void initAnimationSystem() 
{
	int i;
	for(i=0; i<MAX_ANIMATIONS; i++) {
		_animationList[i] = NULL;
	}
}

int createResizeAnimation(CGSWindow *pWidList, int nWids, CGAffineTransform *startTransform, CGAffineTransform *endTransform, float startAlpha, float endAlpha, int duration)
{
	int i, handle;
	_Animation *anim;
	CGSConnection cid;
	
	cid = _CGSDefaultConnection();
	
	/* Find a free handle. */
	i=0;
	while((i < MAX_ANIMATIONS) && (_animationList[i] != NULL)) { i++; }
	
	if(i == MAX_ANIMATIONS) {
		return -1;
	}
	
	handle = i;
	
	anim = (_Animation*) malloc(sizeof(_Animation));
	_animationList[i] = anim;
	
	anim->pWidList = malloc(nWids * sizeof(CGSWindow));
	memcpy(anim->pWidList, pWidList, nWids * sizeof(CGSWindow));
	anim->pOrigTransforms = malloc(nWids * sizeof(CGAffineTransform));
	anim->pOrigAlphas = malloc(nWids * sizeof(float));
	anim->nWids = nWids;
	
	anim->startTransform = *startTransform;
	anim->endTransform = *endTransform;
	anim->startAlpha = startAlpha;
	anim->endAlpha = endAlpha;
	anim->duration = duration;
	anim->progress = 0;

	for(i=0; i<anim->nWids; i++)
	{
		CGSGetWindowTransform(cid,anim->pWidList[i],&(anim->pOrigTransforms[i]));
		CGSGetWindowAlpha(cid,anim->pWidList[i],&(anim->pOrigAlphas[i]));
	}
	
	return handle;
}

void freeResizeAnimation(int animationHandle)
{
	_Animation *anim;
	
	if(!_animationList[animationHandle])
		return;
	
	anim = _animationList[animationHandle];
	free(anim->pWidList);
	free(anim->pOrigTransforms);
	free(anim->pOrigAlphas);
	free(anim);
	_animationList[animationHandle] = NULL;
}

/* dt = 0.02 sec */
#define DT 20000
#define LINTERP(a,b,l) ((l*b) + ((1.0-l)*a))

void performAnimations(int *pAnimationHandles, int nHandles, int reverse)
{
	CGSConnection cid;
	int totalDuration = 0;
	int i, t;
	int timescale = 1;
	CGAffineTransform *transforms;
	
	cid = _CGSDefaultConnection();
	
	/* If shift is held down make the animation slow. */
	if(GetCurrentKeyModifiers() & (1 << 9)) {
		timescale = 8;
	}
	
	/* Find the total duration */
	for(i=0; i<nHandles; i++)
	{
		int j;
		CGSWindowTag tags[2];
		
		tags[0] = CGSTagNoShadow;
		tags[1] = 0;
		
		_Animation *anim = _animationList[pAnimationHandles[i]];
		if(!anim)
			continue;
		
		if(anim->duration > totalDuration)
			totalDuration = anim->duration;
		
		for(j=0; j<anim->nWids; j++)
		{
			CGSSetWindowTags(cid,anim->pWidList[j],tags,32);
		}
	}
	
	transforms = malloc(100 * sizeof(CGAffineTransform));
	
	for(t=0; t<totalDuration * timescale; t+=DT)
	{
		for(i=0; i<nHandles; i++)
		{
			int j;
			float lambda;
			_Animation *anim = _animationList[pAnimationHandles[i]];
			CGAffineTransform trans;
			float alpha;
			
			if(!anim)
				continue;
			
			lambda = (float)(t) / (float)(anim->duration * timescale);
			
			if(lambda < 0.0)
				lambda = 0.0;
			if(lambda > 1.0)
				lambda = 1.0;
			
			lambda = 1.0 - (0.5 + 0.5*cos(lambda * M_PI));

			if(lambda < 0.0)
				lambda = 0.0;
			if(lambda > 1.0)
				lambda = 1.0;
			
			if(reverse) {
				lambda = 1.0 - lambda;
			}
			
			trans.a = LINTERP(anim->startTransform.a, anim->endTransform.a, lambda);
			trans.b = LINTERP(anim->startTransform.b, anim->endTransform.b, lambda);
			trans.c = LINTERP(anim->startTransform.c, anim->endTransform.c, lambda);
			trans.d = LINTERP(anim->startTransform.d, anim->endTransform.d, lambda);

			trans.tx = LINTERP(anim->startTransform.tx, anim->endTransform.tx, lambda);
			trans.ty = LINTERP(anim->startTransform.ty, anim->endTransform.ty, lambda);
			
			alpha = LINTERP(anim->startAlpha, anim->endAlpha, lambda);
			
			for(j=0; j<anim->nWids; j++) 
			{
				transforms[j] = CGAffineTransformConcat(trans, anim->pOrigTransforms[j]);
			}
			
			CGSSetWindowListAlpha(cid,anim->pWidList,anim->nWids,alpha);
			CGSSetWindowTransforms(cid,anim->pWidList,transforms,anim->nWids);
		}
		usleep(DT);
	}
	
	/* Perform final transform */
	for(i=0; i<nHandles; i++)
	{
		int j;
		_Animation *anim = _animationList[pAnimationHandles[i]];
		
		if(!anim)
			continue;
		
		for(j=0; j<anim->nWids; j++) 
		{
			transforms[j] = CGAffineTransformConcat(reverse ? anim->startTransform : anim->endTransform, anim->pOrigTransforms[j]);
		}
		
		CGSSetWindowListAlpha(cid,anim->pWidList,anim->nWids,reverse ? anim->startAlpha : anim->endAlpha);
		CGSSetWindowTransforms(cid,anim->pWidList,transforms,anim->nWids);
	}
	
	
	free(transforms);
	
	for(i=0; i<nHandles; i++)
	{
		int j;
		CGSWindowTag tags[2];
		
		tags[0] = CGSTagNoShadow;
		tags[1] = 0;
		
		_Animation *anim = _animationList[pAnimationHandles[i]];
		if(!anim)
			continue;
		
		if(reverse) 
		{
			for(j=0; j<anim->nWids; j++)
			{
				CGSClearWindowTags(cid,anim->pWidList[j],tags,32);
			}
		}
	}
}
