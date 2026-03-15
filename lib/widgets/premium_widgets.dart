import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../theme/app_theme.dart';
import '../models/post_model.dart';
import 'safe_network_image.dart';

// ... (previous widgets: PremiumGlassCard, PremiumButton, PremiumGlassTextField, PremiumStatCard, AnimatedParticle, ShimmerLoading)

/// Pinterest-Style Post Card for Grids
class PinterestPostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onComment;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  const PinterestPostCard({
    Key? key,
    required this.post,
    this.onLike,
    this.onSave,
    this.onComment,
    this.onTap,
    this.onMore,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image Container - The main attraction
        Expanded(
          child: Stack(
            children: [
              GestureDetector(
                onDoubleTap: onLike,
                onTap: onTap,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.grey.shade100,
                      child: _buildPostImage(post.imageUrl),
                    ),
                  ),
                ),
              ),
              // Hover-style Save Button (Overlay)
              Positioned(
                top: 14,
                right: 14,
                child: GestureDetector(
                  onTap: onSave,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: post.isSaved ? AppTheme.primaryGreen : Colors.white.withOpacity(0.95),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8),
                      ],
                    ),
                    child: Icon(
                      post.isSaved ? FontAwesomeIcons.solidBookmark : FontAwesomeIcons.bookmark,
                      size: 14,
                      color: post.isSaved ? Colors.white : AppTheme.deepNavy,
                    ),
                  ),
                ),
              ),
              // Stats Chip
              Positioned(
                bottom: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        post.isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                        color: post.isLiked ? Colors.pinkAccent : Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likes}',
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onComment,
                        child: Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              '${post.comments}',
                              style: GoogleFonts.manrope(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Minimalist Info area
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.deepNavy,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade100, width: 1.5),
                      color: AppTheme.backgroundLight,
                    ),
                    child: ClipOval(
                      child: Image.network(
                        post.userAvatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.person, size: 14, color: AppTheme.textMuted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      post.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onMore != null)
                    GestureDetector(
                      onTap: onMore,
                      child: const Icon(Icons.more_horiz, size: 18, color: AppTheme.textMuted),
                    ),
                ],
              ),
              if (post.isSaved && post.personalNote != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.edit_note_rounded, size: 16, color: AppTheme.primaryGreen),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          post.personalNote!,
                          style: GoogleFonts.caveat(
                            fontSize: 15,
                            color: AppTheme.deepNavy,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostImage(String url) {
    if (url.isEmpty) {
      return Container(
        color: Colors.grey.shade100,
        child: Center(
          child: Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 24),
        ),
      );
    }

    // Sur le web, les blob URLs et URLs r\u00e9seau utilisent SafeNetworkImage pour \u00e9viter les ProgressEvent erreurs
    if (kIsWeb || url.startsWith('http') || url.startsWith('blob:')) {
      return SafeNetworkImage(
        url,
        fit: BoxFit.cover,
        placeholder: Container(
          color: Colors.grey.shade100,
          child: Center(
            child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade400, size: 24),
          ),
        ),
      );
    } else {
      return Image.file(
        File(url),
        fit: BoxFit.cover,
        errorBuilder: (c, o, s) => Container(
          color: Colors.grey.shade100,
          child: Center(
            child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade400, size: 24),
          ),
        ),
      );
    }
  }
}

/// Grid Skeleton Loader
class GridSkeletonLoader extends StatelessWidget {
  const GridSkeletonLoader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.65,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => ShimmerLoading(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          childCount: 6,
        ),
      ),
    );
  }
}

/// Premium Glass Card with Glassmorphism Effect
class PremiumGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double blur;
  final Color? backgroundColor;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  const PremiumGlassCard({
    Key? key,
    required this.child,
    this.padding,
    this.borderRadius = 24,
    this.blur = 10,
    this.backgroundColor,
    this.borderColor,
    this.boxShadow,
    this.width,
    this.height,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // OPTIMIZATION: Return simple container on web, but avoid MouseRegion which causes tracker crashes
    if (kIsWeb) {
      Widget webContent = Container(
        width: width,
        height: height,
        padding: padding ?? const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: borderColor ?? Colors.white.withOpacity(0.5),
            width: 1.0,
          ),
          boxShadow: boxShadow ?? AppTheme.tightShadow,
        ),
        child: child,
      );

      if (onTap != null) {
        return GestureDetector(onTap: onTap, child: webContent);
      }
      return webContent;
    }

    // MOBILE: Full Premium Effect
    Widget content = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.surfaceWhite.withOpacity(0.85),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.6),
          width: 1.0,
        ),
        boxShadow: boxShadow ?? AppTheme.premiumShadow,
      ),
      child: child,
    );

    if (blur > 0) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      );
    } else {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      );
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}

/// Premium Gradient Button with Loading State
class PremiumButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final List<Color>? gradientColors;
  final double height;
  final double borderRadius;
  final bool isGhost;

  const PremiumButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.gradientColors,
    this.height = 56,
    this.borderRadius = 16,
    this.isGhost = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget buttonContent = Center(
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2.5,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  text,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isGhost ? AppTheme.primaryGreen : Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 10),
                  Icon(
                    icon,
                    color: isGhost ? AppTheme.primaryGreen : Colors.white,
                    size: 20,
                  ),
                ],
              ],
            ),
    );

    if (isGhost) {
      return GestureDetector(
        onTap: isLoading ? null : onPressed,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: AppTheme.primaryGreen, width: 1.5),
          ),
          child: buttonContent,
        ),
      );
    }

    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors ?? [AppTheme.gradientStart, AppTheme.gradientEnd],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: (gradientColors?.first ?? AppTheme.primaryGreen).withOpacity(0.3),
              blurRadius: kIsWeb ? 10 : 20,
              offset: const Offset(0, kIsWeb ? 4 : 8),
            ),
          ],
        ),
        child: buttonContent,
      ),
    );
  }
}

/// Premium Glass TextField
class PremiumGlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;

  const PremiumGlassTextField({
    Key? key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const effectiveBlur = kIsWeb ? 0.0 : 5.0;

    Widget content = Container(
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryGreen.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: GoogleFonts.manrope(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: AppTheme.deepNavy,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: GoogleFonts.manrope(
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w600,
          ),
          hintStyle: GoogleFonts.manrope(
            color: AppTheme.textMuted.withOpacity(0.5),
          ),
          prefixIcon: icon != null
              ? Icon(
                  icon,
                  color: AppTheme.primaryGreen,
                  size: 22,
                )
              : null,
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );

    if (effectiveBlur > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
          child: content,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: content,
    );
  }
}

/// Premium Stat Card (Nouveau Widget)
class PremiumStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const PremiumStatCard({
    Key? key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppTheme.primaryGreen,
    this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppTheme.successLeaf,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppTheme.deepNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated Particle Widget
class AnimatedParticle extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const AnimatedParticle({
    Key? key,
    this.size = 4,
    this.color = AppTheme.primaryGreen,
    this.opacity = 0.3,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(opacity),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(opacity * 0.5),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }
}

/// Shimmer Loading Effect
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const ShimmerLoading({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
  }) : super(key: key);

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Colors.white24,
                Colors.white,
                Colors.white24,
              ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}
