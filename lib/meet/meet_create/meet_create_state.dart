import 'package:image_picker/image_picker.dart';
import '../domain/meet_model.dart';
import '../domain/meet_region.dart';

class MeetCreateState {
  final int step;

  final String title;
  final String intro;
  final String? category;
  final List<MeetRegion> regions;

  final String maxMembersText;
  final bool needApproval;

  // ✅ 수정 재사용 핵심
  final String? editingMeetId;              // null이면 생성, 있으면 수정
  final String? existingThumbnailUrl;       // 기존 썸네일 URL
  final bool removeExistingThumbnail;       // 기존 삭제 플래그
  final XFile? thumbnail;                   // 새로 고른 로컬 썸네일(교체용)

  final bool isLoading;
  final String? errorMessage;

  const MeetCreateState({
    required this.step,
    required this.title,
    required this.intro,
    required this.category,
    required this.regions,
    required this.maxMembersText,
    required this.needApproval,
    required this.editingMeetId,
    required this.existingThumbnailUrl,
    required this.removeExistingThumbnail,
    required this.thumbnail,
    required this.isLoading,
    required this.errorMessage,
  });

  factory MeetCreateState.initial() => const MeetCreateState(
    step: 0,
    title: '',
    intro: '',
    category: null,
    regions: [],
    maxMembersText: '',
    needApproval: false,
    editingMeetId: null,
    existingThumbnailUrl: null,
    removeExistingThumbnail: false,
    thumbnail: null,
    isLoading: false,
    errorMessage: null,
  );

  int? get maxMembersParsed => int.tryParse(maxMembersText.trim());

  bool get isEdit => editingMeetId != null;

  bool get isLast => step == 5; // ✅ 총 6단계(0~5)

  bool get canGoNext {
    switch (step) {
      case 0:
        return title.trim().isNotEmpty && intro.trim().isNotEmpty;
      case 1:
        return category != null;
      case 2:
        return regions.isNotEmpty;
      case 3:
        final v = maxMembersParsed;
        return v != null && v >= 2 && v <= 1000;
      case 4:
        return true;
      case 5:
      // 썸네일 필수로 유지할지 선택
        return thumbnail != null ||
            (existingThumbnailUrl != null && !removeExistingThumbnail);
      default:
        return false;
    }
  }

  MeetCreateState copyWith({
    int? step,
    String? title,
    String? intro,
    String? category,
    List<MeetRegion>? regions,
    String? maxMembersText,
    bool? needApproval,

    String? editingMeetId,
    String? existingThumbnailUrl,
    bool? removeExistingThumbnail,

    XFile? thumbnail,
    bool clearThumbnail = false,
    bool clearExistingThumbnailUrl = false,

    bool? isLoading,
    String? errorMessage,
  }) {
    return MeetCreateState(
      step: step ?? this.step,
      title: title ?? this.title,
      intro: intro ?? this.intro,
      category: category ?? this.category,
      regions: regions ?? this.regions,
      maxMembersText: maxMembersText ?? this.maxMembersText,
      needApproval: needApproval ?? this.needApproval,
      editingMeetId: editingMeetId ?? this.editingMeetId,
      existingThumbnailUrl: clearExistingThumbnailUrl
          ? null
          : (existingThumbnailUrl ?? this.existingThumbnailUrl),
      removeExistingThumbnail:
      removeExistingThumbnail ?? this.removeExistingThumbnail,
      thumbnail: clearThumbnail ? null : (thumbnail ?? this.thumbnail),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}
