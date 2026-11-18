import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/overlays.dart';
import '../../data/models.dart';

/// Article image, or a tinted placeholder while it loads, when the feed has
/// no image, or when the image cannot be shown.
class NewsImage extends StatelessWidget {
  const NewsImage({super.key, required this.article, this.radius = 16});

  final NewsArticle article;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.sky.withValues(alpha: 0.75),
            AppColors.pink.withValues(alpha: 0.35),
          ],
        ),
      ),
      child: const Center(
        child: AppIcon('charging', size: 26, color: AppColors.white),
      ),
    );
    final url = article.imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null
          ? placeholder
          : Image.network(
              url,
              fit: BoxFit.cover,
              // Fades in over the placeholder instead of popping in.
              frameBuilder: (_, child, frame, wasSync) => Stack(
                fit: StackFit.expand,
                children: [
                  placeholder,
                  AnimatedOpacity(
                    opacity: frame == null && !wasSync ? 0 : 1,
                    duration: AppMotion.of(context, AppMotion.slow),
                    curve: AppMotion.enter,
                    child: child,
                  ),
                ],
              ),
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

/// Small round mark with the source's initial.
class SourceMark extends StatelessWidget {
  const SourceMark(this.source, {super.key, this.size = 22});

  final String source;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
          color: AppColors.pinkSoft, shape: BoxShape.circle),
      child: Text(
        source.isEmpty ? '?' : source[0].toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.5,
          fontWeight: FontWeight.w700,
          color: AppColors.pinkDeep,
        ),
      ),
    );
  }
}

/// Large lead story with the headline over the image.
class FeaturedArticleCard extends StatelessWidget {
  const FeaturedArticleCard({super.key, required this.article});

  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    final a = article;
    return Pressable(
      onTap: () => pushScreen(context, ArticleScreen(article: a)),
      label: a.title,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 1.25,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(tag: 'news-${a.id}', child: NewsImage(article: a, radius: 0)),
              // Darkens the lower part so the headline stays readable on any
              // photo.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.25, 1],
                    colors: [
                      AppColors.ink.withValues(alpha: 0),
                      AppColors.ink.withValues(alpha: 0.88),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SourceMark(a.source),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            a.source,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (a.isSample) const Tag('Sample', tone: Tone.warning),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      a.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 20,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeAgo(a.publishedAt),
                      style: TextStyle(
                          color: AppColors.white.withValues(alpha: 0.85),
                          fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One story in the feed: source and date, headline, thumbnail.
class ArticleRow extends StatelessWidget {
  const ArticleRow({super.key, required this.article});

  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    final a = article;
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: () => pushScreen(context, ArticleScreen(article: a)),
      label: a.title,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SourceMark(a.source),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(a.source,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(fontSize: 13)),
                ),
                if (a.isSample) ...[
                  const Tag('Sample', tone: Tone.warning),
                  const SizedBox(width: 8),
                ],
                Text(timeAgo(a.publishedAt), style: text.bodySmall),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16.5,
                            height: 1.3,
                            fontWeight: FontWeight.w600),
                      ),
                      if (a.summary.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          a.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.4,
                              color: AppColors.inkSoft),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 76,
                  height: 76,
                  child: Hero(
                      tag: 'news-${a.id}', child: NewsImage(article: a)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Reading view for one story.
///
/// It shows the publisher's headline, image and summary, then opens the full
/// article on the publisher's own site in an in-app browser. EVYAHE does not
/// copy article bodies.
class ArticleScreen extends StatelessWidget {
  const ArticleScreen({super.key, required this.article});

  final NewsArticle article;

  Future<void> _open(BuildContext context) async {
    final ok = await launchUrl(
      Uri.parse(article.url!),
      mode: LaunchMode.inAppBrowserView,
    );
    if (!ok && context.mounted) {
      showToast(context, 'Could not open the article.', success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = article;
    final url = a.url;
    final serif = GoogleFonts.sourceSerif4(color: AppColors.ink);
    return DetailScaffold(
      title: 'EV news',
      actions: [
        if (url != null)
          IconSquare(
            icon: 'copy',
            label: 'Copy link',
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (context.mounted) showToast(context, 'Link copied.');
            },
          ),
      ],
      bottom: url == null
          ? null
          : AppButton(
              label: 'Read the full article',
              icon: 'arrow',
              expand: true,
              onTap: () => _open(context),
            ),
      children: [
        Row(
          children: [
            SourceMark(a.source, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.source,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(fmtDateTime(a.publishedAt),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Tag(a.philippines ? 'Philippines' : 'World',
                tone: a.philippines ? Tone.sky : Tone.neutral),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          a.title,
          style: serif.copyWith(
              fontSize: 28, height: 1.2, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 18),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Hero(tag: 'news-${a.id}', child: NewsImage(article: a)),
        ),
        const SizedBox(height: 20),
        if (a.summary.isNotEmpty)
          Text(a.summary, style: serif.copyWith(fontSize: 18, height: 1.6)),
        const SizedBox(height: 20),
        NoticeBox(
          a.isSample
              ? 'This is a sample item. Connect the backend to see real EV news from Philippine publishers, refreshed every day.'
              : 'This is the publisher\'s own summary. The full story is on ${a.source}, and opens there.',
          tone: a.isSample ? Tone.warning : Tone.sky,
        ),
      ],
    );
  }
}
