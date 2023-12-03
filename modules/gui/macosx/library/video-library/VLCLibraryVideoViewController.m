/*****************************************************************************
 * VLCLibraryVideoViewController.m: MacOS X interface module
 *****************************************************************************
 * Copyright (C) 2022 VLC authors and VideoLAN
 *
 * Authors: Claudio Cambra <developer@claudiocambra.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#import "VLCLibraryVideoViewController.h"

#import "extensions/NSString+Helpers.h"

#import "library/VLCLibraryController.h"
#import "library/VLCLibraryModel.h"
#import "library/VLCLibraryTableCellView.h"
#import "library/VLCLibraryTwoPaneSplitViewDelegate.h"
#import "library/VLCLibraryUIUnits.h"
#import "library/VLCLibraryWindow.h"
#import "library/VLCLibraryWindowPersistentPreferences.h"

#import "library/audio-library/VLCLibraryAudioViewController.h"

#import "library/video-library/VLCLibraryVideoCollectionViewsStackViewController.h"
#import "library/video-library/VLCLibraryVideoCollectionViewContainerViewDataSource.h"
#import "library/video-library/VLCLibraryVideoTableViewDataSource.h"
#import "library/video-library/VLCLibraryVideoTableViewDelegate.h"

#import "main/VLCMain.h"

#import "windows/video/VLCVoutView.h"
#import "windows/video/VLCMainVideoViewController.h"

@interface VLCLibraryVideoViewController ()
{
    VLCLibraryVideoTableViewDelegate *_videoLibraryTableViewDelegate;
    VLCLibraryTwoPaneSplitViewDelegate *_splitViewDelegate;

    id<VLCMediaLibraryItemProtocol> _awaitingPresentingLibraryItem;
}
@end

@implementation VLCLibraryVideoViewController

- (instancetype)initWithLibraryWindow:(VLCLibraryWindow *)libraryWindow
{
    self = [super init];

    if(self) {
        _videoLibraryTableViewDelegate = [[VLCLibraryVideoTableViewDelegate alloc] init];
        _splitViewDelegate = [[VLCLibraryTwoPaneSplitViewDelegate alloc] init];

        [self setupPropertiesFromLibraryWindow:libraryWindow];
        [self setupTableViewDataSource];
        [self setupTableViews];
        [self setupVideoPlaceholderView];
        [self setupVideoLibraryViews];

        NSNotificationCenter *notificationCenter = NSNotificationCenter.defaultCenter;
        [notificationCenter addObserver:self
                               selector:@selector(libraryModelUpdated:)
                                   name:VLCLibraryModelVideoMediaListReset
                                 object:nil];
        [notificationCenter addObserver:self
                               selector:@selector(libraryModelUpdated:)
                                   name:VLCLibraryModelVideoMediaItemDeleted
                                 object:nil];
    }

    return self;
}

- (void)setupPropertiesFromLibraryWindow:(VLCLibraryWindow *)libraryWindow
{
    NSParameterAssert(libraryWindow);
    _libraryWindow = libraryWindow;
    _libraryTargetView = libraryWindow.libraryTargetView;
    _videoLibraryView = libraryWindow.videoLibraryView;
    _videoLibrarySplitView = libraryWindow.videoLibrarySplitView;
    _videoLibraryCollectionViewScrollView = libraryWindow.videoLibraryCollectionViewScrollView;
    _videoLibraryCollectionView = libraryWindow.videoLibraryCollectionView;
    _videoLibraryGroupSelectionTableViewScrollView = libraryWindow.videoLibraryGroupSelectionTableViewScrollView;
    _videoLibraryGroupSelectionTableView = libraryWindow.videoLibraryGroupSelectionTableView;
    _videoLibraryGroupsTableViewScrollView = libraryWindow.videoLibraryGroupsTableViewScrollView;
    _videoLibraryGroupsTableView = libraryWindow.videoLibraryGroupsTableView;

    _segmentedTitleControl = libraryWindow.segmentedTitleControl;
    _placeholderImageView = libraryWindow.placeholderImageView;
    _placeholderLabel = libraryWindow.placeholderLabel;
    _emptyLibraryView = libraryWindow.emptyLibraryView;
}

- (void)setupTableViewDataSource
{
    _videoLibrarySplitView.delegate = _splitViewDelegate;
    _libraryVideoDataSource = [[VLCLibraryVideoTableViewDataSource alloc] init];
    _libraryVideoDataSource.libraryModel = VLCMain.sharedInstance.libraryController.libraryModel;
    _libraryVideoDataSource.groupsTableView = _videoLibraryGroupsTableView;
    _libraryVideoDataSource.groupSelectionTableView = _videoLibraryGroupSelectionTableView;

    NSNib * const tableCellViewNib = [[NSNib alloc] initWithNibNamed:NSStringFromClass(VLCLibraryTableCellView.class) bundle:nil];
    [_videoLibraryGroupsTableView registerNib:tableCellViewNib forIdentifier:@"VLCVideoLibraryTableViewCellIdentifier"];
    [_videoLibraryGroupSelectionTableView registerNib:tableCellViewNib forIdentifier:@"VLCVideoLibraryTableViewCellIdentifier"];
}

- (void)setupTableViews
{
    _videoLibraryGroupsTableView.dataSource = _libraryVideoDataSource;
    _videoLibraryGroupsTableView.target = _libraryVideoDataSource;
    _videoLibraryGroupsTableView.delegate = _videoLibraryTableViewDelegate;

    _videoLibraryGroupSelectionTableView.dataSource = _libraryVideoDataSource;
    _videoLibraryGroupSelectionTableView.target = _libraryVideoDataSource;
    _videoLibraryGroupSelectionTableView.delegate = _videoLibraryTableViewDelegate;
}

- (void)setupVideoPlaceholderView
{
    _videoPlaceholderImageViewSizeConstraints = @[
        [NSLayoutConstraint constraintWithItem:_placeholderImageView
                                     attribute:NSLayoutAttributeWidth
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:nil
                                     attribute:NSLayoutAttributeNotAnAttribute
                                    multiplier:0.f
                                      constant:182.f],
        [NSLayoutConstraint constraintWithItem:_placeholderImageView
                                     attribute:NSLayoutAttributeHeight
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:nil
                                     attribute:NSLayoutAttributeNotAnAttribute
                                    multiplier:0.f
                                      constant:114.f],
    ];
}

- (void)setupVideoLibraryViews
{
    _videoLibraryGroupsTableView.rowHeight = VLCLibraryUIUnits.mediumTableViewRowHeight;
    _videoLibraryGroupSelectionTableView.rowHeight = VLCLibraryUIUnits.mediumTableViewRowHeight;

    const NSEdgeInsets defaultInsets = VLCLibraryUIUnits.libraryViewScrollViewContentInsets;
    const NSEdgeInsets scrollerInsets = VLCLibraryUIUnits.libraryViewScrollViewScrollerInsets;

    _videoLibraryCollectionViewScrollView.automaticallyAdjustsContentInsets = NO;
    _videoLibraryCollectionViewScrollView.contentInsets = defaultInsets;
    _videoLibraryCollectionViewScrollView.scrollerInsets = scrollerInsets;

    _videoLibraryGroupsTableViewScrollView.automaticallyAdjustsContentInsets = NO;
    _videoLibraryGroupsTableViewScrollView.contentInsets = defaultInsets;
    _videoLibraryGroupsTableViewScrollView.scrollerInsets = scrollerInsets;
    _videoLibraryGroupSelectionTableViewScrollView.automaticallyAdjustsContentInsets = NO;
    _videoLibraryGroupSelectionTableViewScrollView.contentInsets = defaultInsets;
    _videoLibraryGroupSelectionTableViewScrollView.scrollerInsets = scrollerInsets;
}

#pragma mark - Show the video library view

- (void)updatePresentedView
{
    if (_libraryVideoDataSource.libraryModel.numberOfVideoMedia == 0) { // empty library
        [self presentPlaceholderVideoLibraryView];
    } else {
        [self presentVideoLibraryView];
    }
}

- (void)presentVideoView
{
    _libraryTargetView.subviews = @[];
    [self updatePresentedView];
}

- (void)presentPlaceholderVideoLibraryView
{
    for (NSLayoutConstraint *constraint in _libraryWindow.libraryAudioViewController.audioPlaceholderImageViewSizeConstraints) {
        constraint.active = NO;
    }
    for (NSLayoutConstraint *constraint in _videoPlaceholderImageViewSizeConstraints) {
        constraint.active = YES;
    }

    _emptyLibraryView.translatesAutoresizingMaskIntoConstraints = NO;
    _libraryTargetView.subviews = @[_emptyLibraryView];
    NSDictionary *dict = NSDictionaryOfVariableBindings(_emptyLibraryView);
    [_libraryTargetView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_emptyLibraryView(>=572.)]|" options:0 metrics:0 views:dict]];
    [_libraryTargetView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_emptyLibraryView(>=444.)]|" options:0 metrics:0 views:dict]];

    _placeholderImageView.image = [NSImage imageNamed:@"placeholder-video"];
    _placeholderLabel.stringValue = _NS("Your favorite videos will appear here.\nGo to the Browse section to add videos you love.");
}

- (void)presentVideoLibraryView
{
    _videoLibraryView.translatesAutoresizingMaskIntoConstraints = NO;
    _libraryTargetView.subviews = @[_videoLibraryView];

    NSDictionary *dict = NSDictionaryOfVariableBindings(_videoLibraryView);
    [_libraryTargetView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_videoLibraryView(>=572.)]|" options:0 metrics:0 views:dict]];
    [_libraryTargetView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_videoLibraryView(>=444.)]|" options:0 metrics:0 views:dict]];

    const VLCLibraryViewModeSegment viewModeSegment = VLCLibraryWindowPersistentPreferences.sharedInstance.videoLibraryViewMode;

    if (viewModeSegment == VLCLibraryGridViewModeSegment) {
        _videoLibrarySplitView.hidden = YES;
        _videoLibraryCollectionViewScrollView.hidden = NO;
    } else if (viewModeSegment == VLCLibraryListViewModeSegment) {
        _videoLibrarySplitView.hidden = NO;
        _videoLibraryCollectionViewScrollView.hidden = YES;
    } else {
        NSAssert(false, @"View mode must be grid or list mode");
    }
    [self.libraryVideoDataSource reloadData];
}

- (void)libraryModelUpdated:(NSNotification *)aNotification
{
    NSParameterAssert(aNotification);
    VLCLibraryModel *model = VLCMain.sharedInstance.libraryController.libraryModel;
    const NSUInteger videoCount = model.numberOfVideoMedia;

    if (_segmentedTitleControl.selectedSegment == VLCLibraryVideoSegment &&
        ((videoCount == 0 && ![_libraryTargetView.subviews containsObject:_emptyLibraryView]) ||
         (videoCount > 0 && ![_libraryTargetView.subviews containsObject:_videoLibraryView])) &&
        _libraryWindow.videoViewController.view.hidden) {

        [self updatePresentedView];
    }
}

- (void)presentLibraryItemWaitForCollectionViewDataSourceFinished:(NSNotification *)notification
{
    [NSNotificationCenter.defaultCenter removeObserver:self
                                                  name:VLCLibraryVideoCollectionViewDataSourceDisplayedCollectionChangedNotification
                                                object:self.libraryVideoDataSource];

    // TODO: Present for collection view
    _awaitingPresentingLibraryItem = nil;
}

- (void)presentLibraryItemWaitForTableViewDataSourceFinished:(NSNotification *)notification
{
    [NSNotificationCenter.defaultCenter removeObserver:self
                                                  name:VLCLibraryVideoTableViewDataSourceDisplayedCollectionChangedNotification
                                             object:self.libraryVideoDataSource];

    const NSInteger rowForLibraryItem = [self.libraryVideoDataSource rowForLibraryItem:_awaitingPresentingLibraryItem];
    if (rowForLibraryItem != NSNotFound) {
        NSIndexSet * const indexSet = [NSIndexSet indexSetWithIndex:rowForLibraryItem];
        [self.videoLibraryGroupsTableView selectRowIndexes:indexSet byExtendingSelection:NO];
        [self.videoLibraryGroupsTableView scrollRowToVisible:rowForLibraryItem];
    }

    _awaitingPresentingLibraryItem = nil;
}

- (void)presentLibraryItem:(id<VLCMediaLibraryItemProtocol>)libraryItem
{
    if (libraryItem == nil) {
        return;
    }

    _awaitingPresentingLibraryItem = libraryItem;

     const VLCLibraryViewModeSegment viewModeSegment = VLCLibraryWindowPersistentPreferences.sharedInstance.videoLibraryViewMode;

    if (viewModeSegment == VLCLibraryGridViewModeSegment) {
        [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(presentLibraryItemWaitForTableViewDataSourceFinished:)
                                               name:VLCLibraryVideoTableViewDataSourceDisplayedCollectionChangedNotification
                                             object:self.libraryVideoDataSource];

    } else if (viewModeSegment == VLCLibraryListViewModeSegment) {
        [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(presentLibraryItemWaitForTableViewDataSourceFinished:)
                                               name:VLCLibraryVideoCollectionViewDataSourceDisplayedCollectionChangedNotification
                                             object:self.libraryVideoDataSource];

    } else {
        NSAssert(false, @"View mode must be grid or list mode");
    }
}

@end
