import 'package:flutter/widgets.dart';

// Shared drag-to-reorder geometry and ordering maths.
//
// The three list screens (today / semester / future) each wired their own copy
// of this and drifted apart; these helpers are the parts that were genuinely
// identical, so the hit zones now behave the same everywhere.
enum DropZone { before, into, after }

// Row is split top 1/4 = insert before, middle 1/2 = become a child,
// bottom 1/4 = insert after. When the row can't take children the middle
// half is split between before and after so no part of the row is dead.
//
// IMPORTANT: pointerGlobal must be the actual pointer position. Flutter's
// DragTargetDetails.offset is the top-left of the *feedback widget*, not the
// finger, so passing it raw shifts every zone by wherever the row was grabbed.
// Use pointerDragAnchorStrategy on the Draggable to make them coincide.
DropZone dropZoneFor(
  RenderBox box,
  Offset pointerGlobal, {
  required bool canNest,
}) {
  final localY = box.globalToLocal(pointerGlobal).dy;
  final height = box.size.height;
  if (height <= 0) return DropZone.before;
  final ratio = (localY / height).clamp(0.0, 1.0);
  if (!canNest) return ratio < 0.5 ? DropZone.before : DropZone.after;
  if (ratio < 0.25) return DropZone.before;
  if (ratio < 0.75) return DropZone.into;
  return DropZone.after;
}

// Gap-based ordering: new items land midway between their neighbours so the
// other rows never need rewriting. Items start 1000 apart (see the providers'
// add methods), which allows ~10 successive midpoint inserts before ties.
const int kOrderGap = 1000;

int orderBetween(int? prevOrder, int? nextOrder) {
  if (prevOrder == null && nextOrder == null) return kOrderGap;
  if (prevOrder == null) return nextOrder! - kOrderGap;
  if (nextOrder == null) return prevOrder + kOrderGap;
  return ((prevOrder + nextOrder) / 2).round();
}

int orderAfterLast(Iterable<int> existingOrders) {
  final maxOrder =
      existingOrders.fold(0, (prev, o) => o > prev ? o : prev);
  return maxOrder + kOrderGap;
}
