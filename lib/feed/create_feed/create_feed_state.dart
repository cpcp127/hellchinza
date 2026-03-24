import 'package:image_picker/image_picker.dart';

import '../domain/feed_model.dart';
import '../domain/feed_place.dart';

class CreateFeedState {
  final bool isLoading;
  final int pageIndex;
  final String? selectMainType;
  final String? selectSubType;
  final List<String> existingImageUrls;
  final List<XFile> newImageFiles;
  final List<String> removedImageUrls;
  final String contents;
  final int currentImageIndex;
  final List<String> pollOptions;
  final bool isUploading;
  final FeedPlace? selectedPlace;
  final String visibility;
  final bool isStepTransitioning;
  const CreateFeedState({
    this.pageIndex = 0,
    this.isLoading = false,
    this.selectMainType,
    this.selectSubType,
    this.existingImageUrls = const [],
    this.newImageFiles = const [],
    this.removedImageUrls = const [],
    this.contents = '',
    this.currentImageIndex = 0,
    this.pollOptions = const [],
    this.isUploading = false,
    this.selectedPlace,
    this.visibility = FeedVisibility.public,this.isStepTransitioning=false
  });

  CreateFeedState copyWith({
    int? pageIndex,
    bool? isLoading,
    String? selectMainType,
    String? selectSubType,
    List<String>? existingImageUrls,
    List<XFile>? newImageFiles,
    List<String>? removedImageUrls,
    String? contents,
    int? currentImageIndex,
    List<String>? pollOptions,
    bool? isUploading,
    FeedPlace? selectedPlace,
    String? visibility,
    bool clearPlace = false,bool? isStepTransitioning
  }) {
    return CreateFeedState(
      pageIndex: pageIndex ?? this.pageIndex,
      isLoading: isLoading ?? this.isLoading,
      selectMainType: selectMainType ?? this.selectMainType,
      selectSubType: selectSubType ?? this.selectSubType,
      existingImageUrls: existingImageUrls ?? this.existingImageUrls,
      newImageFiles: newImageFiles ?? this.newImageFiles,
      removedImageUrls: removedImageUrls ?? this.removedImageUrls,
      contents: contents ?? this.contents,
      currentImageIndex: currentImageIndex ?? this.currentImageIndex,
      pollOptions: pollOptions ?? this.pollOptions,
      isUploading: isUploading ?? this.isUploading,
      selectedPlace: clearPlace ? null : (selectedPlace ?? this.selectedPlace),
      visibility: visibility ?? this.visibility,isStepTransitioning: isStepTransitioning ?? this.isStepTransitioning
    );
  }

  CreateFeedState resetForTypeSelect() {
    return CreateFeedState(
      selectMainType: selectMainType,
      selectSubType: selectSubType,
    );
  }
}
