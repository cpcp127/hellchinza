import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hellchinza/feed/domain/naver_place_model.dart';
import 'package:proj4dart/proj4dart.dart' as proj4;

import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';
import '../feed/create_feed/create_feed_state.dart';
import '../services/naver_location_service.dart';
import '../services/snackbar_service.dart';
import 'common_text_field.dart';

class CommonLocationSearchView extends StatefulWidget {
  const CommonLocationSearchView({super.key});

  @override
  State<CommonLocationSearchView> createState() =>
      _CommonLocationSearchViewState();
}

class _CommonLocationSearchViewState extends State<CommonLocationSearchView> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<NaverLocalPlace> results = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('장소 검색')),
      body: Column(
        children: [
          _buildSearchField(),
          Expanded(child: _buildResultList()),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: CommonTextField(
        controller: _controller,

        hintText: '장소명을 검색해보세요',

        suffixIcon: GestureDetector(
          onTap: () async {
            FocusManager.instance.primaryFocus?.unfocus();

            await _search(_controller.text);
          },
          child: Container(
              color: Colors.transparent,
              child: Icon(Icons.search, color: AppColors.icSecondary)),
        ),
      ),
    );
  }

  Widget _buildResultList() {
    if (isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (results.isEmpty) {
      return Center(
        child: Text(
          '검색 결과가 없습니다',
          style: AppTextStyle.bodyMediumStyle.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: AppColors.borderSecondary),
      itemBuilder: (context, index) {
        final place = results[index];
        return ListTile(
          title: Text(place.title, style: AppTextStyle.titleSmallBoldStyle),
          subtitle: Text(
            place.roadAddress.isNotEmpty ? place.roadAddress : place.address,
            style: AppTextStyle.bodySmallStyle.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          onTap: () {
            final p = results[index];

            final mapx = p.mapx;
            final mapy = p.mapy;

            final latLng = tm128ToWgs84(mapx: mapx, mapy: mapy);

            final feedPlace = FeedPlace(
              title: p.title,
              address: p.roadAddress.isNotEmpty ? p.roadAddress : p.address,
              lat: latLng.lat,
              lng: latLng.lng,
            );

            Navigator.pop(context, feedPlace);
          },
        );
      },
    );
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      isLoading = true;
    });

    try {
      final List<NaverLocalPlace> list = await NaverLocationService().search(
        query,
      );

      setState(() {
        results = list; // ✅ 여기!
      });
    } catch (e) {
      setState(() {
        results = [];
      });

      // 필요하면 스낵바
      SnackbarService.show(type: AppSnackType.error, message: '검색에 실패했습니다');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
  LatLng tm128ToWgs84({
    required double mapx,
    required double mapy,
  }) {
    final katech = proj4.Projection.parse(
      '+proj=tmerc +lat_0=38 +lon_0=128 '
          '+k=0.9999 +x_0=400000 +y_0=600000 '
          '+ellps=bessel +units=m +no_defs',
    );

    final wgs84 = proj4.Projection.parse(
      '+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs',
    );

    final pt = proj4.Point(
      x: mapx / 1e7,
      y: mapy / 1e7,
    );

    final out = proj4.ProjectionTuple(fromProj: katech, toProj: wgs84).forward(pt);

    return LatLng(lat: out.y, lng: out.x);
  }
}
