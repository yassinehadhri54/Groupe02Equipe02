import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_theme.dart';

class OfferPhoto extends StatelessWidget {
  const OfferPhoto({required this.imageUrl, this.iconSize = 44, super.key});

  final String imageUrl;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: context.colors.surface,
        highlightColor: context.colors.surfaceContainerHigh,
        child: ColoredBox(color: context.colors.surface),
      ),
      errorWidget: (context, url, error) => ColoredBox(
        color: context.colors.surface,
        child: Center(
          child: Icon(
            Icons.restaurant_outlined,
            size: iconSize,
            color: context.colors.primary,
          ),
        ),
      ),
    );
  }
}
