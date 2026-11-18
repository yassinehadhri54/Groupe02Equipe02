import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../offers/widgets/offer_photo.dart';

class OfferCard extends StatelessWidget {
  const OfferCard({
    required this.name,
    required this.shop,
    required this.imageUrl,
    required this.price,
    required this.oldPrice,
    required this.category,
    required this.onTap,
    super.key,
  });

  final String name;
  final String shop;
  final String imageUrl;
  final double price;
  final double oldPrice;
  final String category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final discount = oldPrice > 0
        ? ((oldPrice - price) / oldPrice * 100).round()
        : 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  OfferPhoto(imageUrl: imageUrl),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.burgundy,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '-$discount%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.gold,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    shop,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppTheme.ink.withValues(alpha: 0.65)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '${price.toStringAsFixed(3)} DT',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppTheme.burgundy,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${oldPrice.toStringAsFixed(3)} DT',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.ink.withValues(alpha: 0.55),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const Spacer(),
                      IconButton.filled(
                        tooltip: 'Voir les détails de $name',
                        onPressed: onTap,
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          foregroundColor: AppTheme.ink,
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
