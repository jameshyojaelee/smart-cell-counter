import UIKit

public enum ObjectFeatures {
    public static func connectedComponents(_ seg: SegmentationResult) -> [[Int]] {
        let w = seg.width, h = seg.height
        var labels = [Int](repeating: 0, count: w*h)
        var current = 0
        var components: [[Int]] = []
        for y in 0..<h {
            for x in 0..<w {
                let idx = y*w + x
                if seg.mask[idx] == 0 || labels[idx] != 0 { continue }
                current += 1
                var stack = [idx]
                var comp: [Int] = []
                labels[idx] = current
                while let p = stack.popLast() {
                    comp.append(p)
                    let px = p % w, py = p / w
                    for ny in max(0, py-1)...min(h-1, py+1) {
                        for nx in max(0, px-1)...min(w-1, px+1) {
                            let q = ny*w + nx
                            if seg.mask[q] != 0 && labels[q] == 0 { labels[q] = current; stack.append(q) }
                        }
                    }
                }
                components.append(comp)
            }
        }
        return components
    }

    public static func features(from seg: SegmentationResult, pxPerMicron: Double?) -> [CellObject] {
        let comps = connectedComponents(seg)
        var objects: [CellObject] = []
        var id = 1
        for comp in comps {
            var minx = Int.max, miny = Int.max, maxx = 0, maxy = 0
            let w = seg.width
            for p in comp { let x = p % w; let y = p / w; if x < minx { minx = x }; if y < miny { miny = y }; if x > maxx { maxx = x }; if y > maxy { maxy = y } }
            let bbox = CellObject.BoundingBox(x: minx, y: miny, width: maxx - minx + 1, height: maxy - miny + 1)
            let areaPx = comp.count
            // Perimeter via 4-neighborhood boundary count
            var perimeter = 0
            for p in comp {
                let x = p % w; let y = p / w
                let neighbors = [(-1,0),(1,0),(0,-1),(0,1)]
                for (dx,dy) in neighbors {
                    let nx = x+dx, ny = y+dy
                    if nx < 0 || ny < 0 || nx >= seg.width || ny >= seg.height || seg.mask[ny*w + nx] == 0 { perimeter += 1 }
                }
            }
            let centroidX = Double(comp.reduce(0) { $0 + ($1 % w) }) / Double(areaPx)
            let centroidY = Double(comp.reduce(0) { $0 + ($1 / w) }) / Double(areaPx)
            let circularity = areaPx == 0 || perimeter == 0 ? 0 : 4.0 * Double.pi * Double(areaPx) / pow(Double(perimeter), 2)
            // Simple solidity approximation: bounding box area as hull proxy
            let solidity = Double(areaPx) / Double(bbox.width * bbox.height)
            let obj = CellObject(id: id, areaPx: areaPx, perimeterPx: perimeter, circularity: circularity, solidity: solidity, centroid: CGPoint(x: centroidX, y: centroidY), bbox: bbox)
            objects.append(obj)
            id += 1
        }
        return objects
    }
}
