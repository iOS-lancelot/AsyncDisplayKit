//
//  ASStackPositionedLayout.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASStackPositionedLayout.h"

#import <tgmath.h>

#import "ASInternalHelpers.h"
#import "ASLayoutSpecUtilities.h"
#import "ASLayoutSpec+Subclasses.h"

static CGFloat crossOffset(const ASStackLayoutSpecStyle &style,
                           const ASStackLayoutSpecItem &l,
                           const CGFloat crossSize)
{
  switch (alignment(l.child.style.alignSelf, style.alignItems)) {
    case ASStackLayoutAlignItemsEnd:
      return crossSize - crossDimension(style.direction, l.layout.size);
    case ASStackLayoutAlignItemsCenter:
      return ASFloorPixelValue((crossSize - crossDimension(style.direction, l.layout.size)) / 2);
    case ASStackLayoutAlignItemsBaselineFirst:
    case ASStackLayoutAlignItemsBaselineLast:
    case ASStackLayoutAlignItemsStart:
    case ASStackLayoutAlignItemsStretch:
      return 0;
  }
}

/**
 * Positions children according to the stack style and positioning properties.
 *
 * @param style The layout style of the overall stack layout
 * @param firstChildOffset Offset of the first child
 * @param extraSpacing Spacing between children, in addition to spacing set to the stack's layout style
 * @param unpositionedLayout Unpositioned children of the stack
 * @param constrainedSize Constrained size of the stack
 */
static ASStackPositionedLayout stackedLayout(const ASStackLayoutSpecStyle &style,
                                             const CGFloat firstChildOffset,
                                             const CGFloat extraSpacing,
                                             const ASStackUnpositionedLayout &unpositionedLayout,
                                             const ASSizeRange &constrainedSize)
{
    
  // The cross dimension is the max of the childrens' cross dimensions (clamped to our constraint below).
  const auto it = std::max_element(unpositionedLayout.items.begin(), unpositionedLayout.items.end(),
                                   [&](const ASStackLayoutSpecItem &a, const ASStackLayoutSpecItem &b){
                                     return compareCrossDimension(style.direction, a.layout.size, b.layout.size);
                                   });
  const auto largestChildCrossSize = it == unpositionedLayout.items.end() ? 0 : crossDimension(style.direction, it->layout.size);
  const auto minCrossSize = crossDimension(style.direction, constrainedSize.min);
  const auto maxCrossSize = crossDimension(style.direction, constrainedSize.max);
  const CGFloat crossSize = MIN(MAX(minCrossSize, largestChildCrossSize), maxCrossSize);
  
  CGPoint p = directionPoint(style.direction, firstChildOffset, 0);
  BOOL first = YES;
  
  // Adjust the position of the unpositioned layouts to be positioned
  const auto stackedChildren = unpositionedLayout.items;
  for (const auto &l : stackedChildren) {
    p = p + directionPoint(style.direction, l.child.style.spacingBefore, 0);
    if (!first) {
      p = p + directionPoint(style.direction, style.spacing + extraSpacing, 0);
    }
    first = NO;
    l.layout.position = p + directionPoint(style.direction, 0, crossOffset(style, l, crossSize));
    
    p = p + directionPoint(style.direction, stackDimension(style.direction, l.layout.size) + l.child.style.spacingAfter, 0);
  }

  return {std::move(stackedChildren), crossSize};
}

ASStackPositionedLayout ASStackPositionedLayout::compute(const ASStackUnpositionedLayout &unpositionedLayout,
                                                         const ASStackLayoutSpecStyle &style,
                                                         const ASSizeRange &constrainedSize)
{
  const auto numOfItems = unpositionedLayout.items.size();
  ASDisplayNodeCAssertTrue(numOfItems > 0);
  const CGFloat violation = unpositionedLayout.violation;
  ASStackLayoutJustifyContent justifyContent = style.justifyContent;
  
  // Handle edge cases of "space between" and "space around"
  if (justifyContent == ASStackLayoutJustifyContentSpaceBetween && (violation < 0 || numOfItems == 1)) {
    justifyContent = ASStackLayoutJustifyContentStart;
  } else if (justifyContent == ASStackLayoutJustifyContentSpaceAround && (violation < 0 || numOfItems == 1)) {
    justifyContent = ASStackLayoutJustifyContentCenter;
  }
  
  switch (justifyContent) {
    case ASStackLayoutJustifyContentStart: {
      return stackedLayout(style, 0, 0, unpositionedLayout, constrainedSize);
    }
    case ASStackLayoutJustifyContentCenter: {
      return stackedLayout(style, std::floor(violation / 2), 0, unpositionedLayout, constrainedSize);
    }
    case ASStackLayoutJustifyContentEnd: {
      return stackedLayout(style, violation, 0, unpositionedLayout, constrainedSize);
    }
    case ASStackLayoutJustifyContentSpaceBetween: {
      // Spacing between the items, no spaces at the edges, evenly distributed
      const auto numOfSpacings = numOfItems - 1;
      return stackedLayout(style, 0, violation / numOfSpacings, unpositionedLayout, constrainedSize);
    }
    case ASStackLayoutJustifyContentSpaceAround: {
      // Spacing between items are twice the spacing on the edges
      CGFloat spacingUnit = violation / (numOfItems * 2);
      return stackedLayout(style, spacingUnit, spacingUnit * 2, unpositionedLayout, constrainedSize);
    }
  }
}
