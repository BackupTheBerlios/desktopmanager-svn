/****************************************************************************************
	mach_inject.c $Revision: 1.1 $
	
	Copyright (c) 2003 Red Shed Software. All rights reserved.
	by Jonathan 'Wolf' Rentzsch (jon * redshed * net)
	
	************************************************************************************/

#include	<mach-o/dyld.h>
#include	<mach-o/getsect.h>
#include	<mach/mach.h>
#include	<sys/stat.h>
#include	<mach/mach_init.h>

#include	<Carbon/Carbon.h>

#include	"mach_inject.h"

#ifndef	COMPILE_TIME_ASSERT( exp )
	#define COMPILE_TIME_ASSERT( exp ) { switch (0) { case 0: case (exp):; } }
#endif
#define ASSERT_CAST( CAST_TO, CAST_FROM )	COMPILE_TIME_ASSERT( sizeof(CAST_TO)==sizeof(CAST_FROM) )

/****************************************************************************************
*	
*	Interface
*	
****************************************************************************************/
#pragma mark	-
#pragma mark	(Interface)

	mach_error_t
mach_inject(
		const mach_inject_entry	threadEntry,
		const void				*paramBlock,
		size_t					paramSize,
		pid_t					targetProcess,
		vm_size_t				stackSize ) {
	;//assertCodePtr( threadEntry );
	;//assertPtrIfNotNull( paramBlock );
	;//assertPositive( targetProcess );
	;//assertIsTrue( stackSize == 0 || stackSize > 1024 );
	
	//	Find the image.
	const void		*image;
	unsigned long	imageSize;
	mach_error_t	err = machImageForPointer( threadEntry, &image, &imageSize );
	
	//	Initialize stackSize to default if requested.
	if( stackSize == 0 )
		/** @bug We only want an 8K default, fix the plop-in-the-middle code below. */
		stackSize = 16 * 1024;
	
	//	Convert PID to Mach Task ref.
	mach_port_t	remoteTask = 0;
	if( !err )
		err = task_for_pid( mach_task_self(), targetProcess, &remoteTask );
	
	/** @todo	Would be nice to just allocate one block for both the remote stack
				*and* the remoteCode (including the parameter data block once that's
				written.
	*/
	
	//	Allocate the remoteStack.
	vm_address_t remoteStack = NULL;
	if( !err )
		err = vm_allocate( remoteTask, &remoteStack, stackSize, 1 );
	
	//	Allocate the code.
	vm_address_t remoteCode = NULL;
	if( !err )
		err = vm_allocate( remoteTask, &remoteCode, imageSize, 1 );
	if( !err ) {
		ASSERT_CAST( pointer_t, image );
		err = vm_write( remoteTask, remoteCode, (pointer_t) image, imageSize );
	}
	
	//	Allocate the paramBlock if specified.
	vm_address_t remoteParamBlock = NULL;
	if( !err && paramBlock != NULL && paramSize ) {
		err = vm_allocate( remoteTask, &remoteParamBlock, paramSize, 1 );
		if( !err ) {
			ASSERT_CAST( pointer_t, paramBlock );
			err = vm_write( remoteTask, remoteParamBlock, (pointer_t) paramBlock, paramSize );
		}
	}
	
	//	Calculate offsets.
	ptrdiff_t	threadEntryOffset, imageOffset;
	if( !err ) {
		;//assertIsWithinRange( threadEntry, image, image+imageSize );
		ASSERT_CAST( void*, threadEntry );
		threadEntryOffset = ((void*) threadEntry) - image;
		
		ASSERT_CAST( void*, remoteCode );
		imageOffset = ((void*) remoteCode) - image;
	}
	
	//	Allocate the thread.
	thread_act_t remoteThread;
	if( !err ) {
		ppc_thread_state_t remoteThreadState;
		
		/** @bug Stack math should be more sophisticated than this (ala redzone). */
		remoteStack += stackSize / 2;
		
		bzero( &remoteThreadState, sizeof(remoteThreadState) );
		
		ASSERT_CAST( unsigned int, remoteCode );
		remoteThreadState.srr0 = (unsigned int) remoteCode;
		remoteThreadState.srr0 += threadEntryOffset;
		assert( remoteThreadState.srr0 < (remoteCode + imageSize) );
		
		ASSERT_CAST( unsigned int, remoteStack );
		remoteThreadState.r1 = (unsigned int) remoteStack;
		
		ASSERT_CAST( unsigned int, imageOffset );
		remoteThreadState.r3 = (unsigned int) imageOffset;
		
		ASSERT_CAST( unsigned int, remoteParamBlock );
		remoteThreadState.r4 = (unsigned int) remoteParamBlock;
		
		ASSERT_CAST( unsigned int, paramSize );
		remoteThreadState.r5 = (unsigned int) paramSize;
		
		ASSERT_CAST( unsigned int, 0xDEADBEEF );
		remoteThreadState.lr = (unsigned int) 0xDEADBEEF;
		
		//printf( "remoteCode start: %p\n", (void*) remoteCode );
		//printf( "remoteCode size: %ld\n", imageSize );
		//printf( "remoteCode pc: %p\n", (void*) remoteThreadState.srr0 );
		//printf( "remoteCode end: %p\n", (void*) (((char*)remoteCode)+imageSize) );
		fflush(0);
		
		err = thread_create_running( remoteTask, PPC_THREAD_STATE,
				(thread_state_t) &remoteThreadState, PPC_THREAD_STATE_COUNT,
				&remoteThread );
	}
	
	if( err ) {
		if( remoteParamBlock )
			vm_deallocate( remoteTask, remoteParamBlock, paramSize );
		if( remoteCode )
			vm_deallocate( remoteTask, remoteCode, imageSize );
		if( remoteStack )
			vm_deallocate( remoteTask, remoteStack, stackSize );
	}
	
	return err;
}

	mach_error_t
machImageForPointer(
		const void *pointer,
		const void **image,
		unsigned long *size ) {
	;//assertCodePtr( pointer );
	;//assertPtr( image );
	;//assertPtr( size );
	
	unsigned long p = (unsigned long) pointer;
	
	unsigned long imageIndex, imageCount = _dyld_image_count();
	for( imageIndex = 0; imageIndex < imageCount; imageIndex++ ) {
		struct mach_header *header = _dyld_get_image_header( imageIndex );
		const struct section *section = getsectbynamefromheader( header, SEG_TEXT, SECT_TEXT );
		long start = section->addr + _dyld_get_image_vmaddr_slide( imageIndex );
		long stop = start + section->size;
		if( p >= start && p <= stop ) {
			//	It is truely insane we have to stat() the file system in order to
			//	discover the size of an in-memory data structure.
			char *imageName = _dyld_get_image_name( imageIndex );
			;//assertPath( imageName );
			struct stat sb;
			if( stat( imageName, &sb ) )
				return unix_err( errno );
			if( image ) {
				ASSERT_CAST( void*, header );
				*image = (void*) header;
			}
			if( size ) {
				;//assertUInt32( st_size );
				*size = sb.st_size;
			}
			return err_none;
		}
	}
	
	return err_threadEntry_image_not_found;
}