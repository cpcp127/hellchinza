import 'package:flutter_image_compress/flutter_image_compress.dart';

class CreateFeedState {
  final bool isLoading;
  final int pageIndex;
  final String? selectMainType;
  final String? selectSubType;
  final List<String>? existingImageUrls; // 기존 이미지 (url)
  final List<XFile>? newImageFiles;       // 새로 추가한 이미지
  final List<String>? removedImageUrls;   // 삭제된 기존 이미지
  final String? contents;
  final int currentImageIndex;
  final List<String>? pollOptions;
  final bool isUploading;
  final FeedPlace? selectedPlace;


  CreateFeedState({
    this.pageIndex = 0,
    this.isLoading = false,
    this.selectMainType,
    this.selectSubType,
    this.existingImageUrls,
    this.newImageFiles,
    this.removedImageUrls,
    this.contents,
    this.currentImageIndex = 0,
    this.pollOptions,
    this.isUploading = false,this.selectedPlace
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
    bool? isUploading,FeedPlace? selectedPlace,
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
      selectedPlace: selectedPlace ?? this.selectedPlace,
    );
  }
}

class FeedPlace {
  final String title;
  final String address;
  final double lat; // WGS84
  final double lng; // WGS84

  const FeedPlace({
    required this.title,
    required this.address,
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'address': address,
    'lat': lat,
    'lng': lng,
  };

  factory FeedPlace.fromJson(Map<String, dynamic> json) => FeedPlace(
    title: (json['title'] ?? '') as String,
    address: (json['address'] ?? '') as String,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
  );
}


extension CreateFeedStateReset on CreateFeedState {
  /// ✅ 유형 선택(selectMainType / selectSubType)은 유지
  /// ❌ 작성 데이터는 전부 초기화
  CreateFeedState resetForTypeSelect() {
    return CreateFeedState(
      // 유지
      selectMainType: selectMainType,
      selectSubType: selectSubType,

      // 초기화
      pageIndex: 0,
      isLoading: false,
      existingImageUrls: null,
      newImageFiles: null,
      removedImageUrls: null,
      contents: null,
      currentImageIndex: 0,
      pollOptions: null,
      isUploading: false,
    );
  }
}
