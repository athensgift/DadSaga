import Domain
import Testing

/// What the film's camera looks at in a photo (ADR-0047 §3).
@Suite("PhotoSubject")
struct PhotoSubjectTests {
    @Test("Given a child and an adult, when finding the subject, then it is the child's face with a margin")
    func childBeforeAdult() throws {
        let child = PhotoRegion(left: 0.1, top: 0.4, width: 0.2, height: 0.2)
        let adult = PhotoRegion(left: 0.6, top: 0.1, width: 0.25, height: 0.25)

        let subject = try #require(PhotoSubject.region(
            faces: [PhotoFace(region: adult, isChild: false), PhotoFace(region: child, isChild: true)],
            salientObjects: []
        ))

        #expect(subject.left < child.left && subject.right > child.right)
        #expect(subject.top < child.top && subject.bottom > child.bottom)
        #expect(subject.right < adult.left)
    }

    @Test("Given two children, when finding the subject, then it holds both")
    func childrenTogether() throws {
        let first = PhotoRegion(left: 0.1, top: 0.4, width: 0.2, height: 0.2)
        let second = PhotoRegion(left: 0.6, top: 0.3, width: 0.2, height: 0.2)

        let subject = try #require(PhotoSubject.region(
            faces: [PhotoFace(region: first, isChild: true), PhotoFace(region: second, isChild: true)],
            salientObjects: []
        ))

        #expect(subject.left < first.left && subject.right > second.right)
    }

    @Test("Given no face looks like a child, when finding the subject, then it holds all the faces")
    func allFacesWithoutChild() throws {
        let one = PhotoRegion(left: 0.1, top: 0.1, width: 0.2, height: 0.2)
        let other = PhotoRegion(left: 0.6, top: 0.5, width: 0.2, height: 0.2)

        let subject = try #require(PhotoSubject.region(
            faces: [PhotoFace(region: one, isChild: false), PhotoFace(region: other, isChild: nil)],
            salientObjects: []
        ))

        #expect(subject.left < one.left && subject.right > other.right && subject.bottom > other.bottom)
    }

    @Test("Given a small face in the background, when finding the subject, then it is left out")
    func backgroundFaceLeftOut() throws {
        let near = PhotoRegion(left: 0.1, top: 0.2, width: 0.3, height: 0.3)
        let far = PhotoRegion(left: 0.85, top: 0.1, width: 0.05, height: 0.05)

        let subject = try #require(PhotoSubject.region(
            faces: [PhotoFace(region: near, isChild: true), PhotoFace(region: far, isChild: true)],
            salientObjects: []
        ))

        #expect(subject.right < far.left)
    }

    @Test("Given no face, when finding the subject, then it is the salient objects; with neither, none")
    func salientWithoutFaces() {
        let ball = PhotoRegion(left: 0.2, top: 0.5, width: 0.1, height: 0.1)
        let dog = PhotoRegion(left: 0.5, top: 0.6, width: 0.2, height: 0.2)

        let subject = PhotoSubject.region(faces: [], salientObjects: [ball, dog])

        #expect(subject?.left == 0.2 && subject?.top == 0.5)
        #expect(abs((subject?.right ?? 0) - 0.7) < 1e-9 && abs((subject?.bottom ?? 0) - 0.8) < 1e-9)
        #expect(PhotoSubject.region(faces: [], salientObjects: []) == nil)
    }

    @Test("Given a face at the photo's edge, when finding the subject, then it stays inside the photo")
    func staysInside() throws {
        let edge = PhotoRegion(left: 0.85, top: 0.85, width: 0.15, height: 0.15)

        let subject = try #require(PhotoSubject.region(faces: [PhotoFace(region: edge, isChild: nil)], salientObjects: []))

        #expect(subject.left >= 0 && subject.top >= 0 && subject.right <= 1 && subject.bottom <= 1)
    }

    @Test("Given faces with and without a child, when framing, then it says whether a child is in it")
    func framingSaysChild() {
        let face = PhotoRegion(left: 0.4, top: 0.3, width: 0.2, height: 0.2)
        func showsChild(_ isChild: Bool?) -> Bool? {
            PhotoSubject.framing(faces: [PhotoFace(region: face, isChild: isChild)], salientObjects: [])?.showsChild
        }

        #expect(showsChild(true) == true)
        #expect(showsChild(false) == false)
        #expect(showsChild(nil) == false)
        #expect(PhotoSubject.framing(faces: [], salientObjects: [face])?.showsChild == false)
    }
}
