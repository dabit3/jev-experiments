import Foundation
import CoreGraphics

// usage: tap X Y | drag X1 Y1 X2 Y2 MS | hold X Y MS | sleep MS   (coordinates in screen points)
func post(_ type: CGEventType, _ p: CGPoint) {
    let e = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)!
    e.post(tap: .cghidEventTap)
}
func ms(_ n: Double) { usleep(useconds_t(n * 1000)) }
func move(_ p: CGPoint) { post(.mouseMoved, p); ms(40) }
func tap(_ p: CGPoint) { move(p); ms(80); post(.leftMouseDown, p); ms(70); post(.leftMouseUp, p) }
func hold(_ p: CGPoint, _ dur: Double) { move(p); ms(80); post(.leftMouseDown, p); ms(dur); post(.leftMouseUp, p) }
func drag(_ a: CGPoint, _ b: CGPoint, _ dur: Double) {
    move(a); ms(80); post(.leftMouseDown, a); ms(120)
    let steps = 40
    for i in 1...steps {
        let t = Double(i) / Double(steps)
        let e = 1 - pow(1 - t, 3)
        let p = CGPoint(x: a.x + (b.x - a.x) * e, y: a.y + (b.y - a.y) * e)
        post(.leftMouseDragged, p); ms(dur / Double(steps))
    }
    ms(120); post(.leftMouseUp, b)
}

var args = Array(CommandLine.arguments.dropFirst())
func num() -> Double { Double(args.removeFirst())! }
while !args.isEmpty {
    let cmd = args.removeFirst()
    switch cmd {
    case "tap": tap(CGPoint(x: num(), y: num()))
    case "hold": let p = CGPoint(x: num(), y: num()); hold(p, num())
    case "drag": let a = CGPoint(x: num(), y: num()); let b = CGPoint(x: num(), y: num()); drag(a, b, num())
    case "move": move(CGPoint(x: num(), y: num()))
    case "sleep": ms(num())
    default: fatalError("unknown \(cmd)")
    }
}
