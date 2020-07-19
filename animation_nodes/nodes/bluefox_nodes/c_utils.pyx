import cython
from libc.math cimport sqrt, M_PI, asin
from .. matrix.c_utils import* 
from ... math cimport abs as absNumber
from mathutils import Matrix, Euler, Vector
from ... math import matrix4x4ListToEulerList
from ... libs.FastNoiseSIMD.wrapper import PyNoise
from ... algorithms.lists.random import generateRandomVectors
from ... algorithms.random import uniformRandomDoubleWithTwoSeeds, getRandom3DVector
from ... nodes.number.c_utils import range_DoubleList_StartStop, mapRange_DoubleList_Interpolated 
from ... data_structures cimport (
    DoubleList, FloatList,VirtualMatrix4x4List,
    Vector3DList, EulerList, Matrix4x4List, QuaternionList,
    VirtualVector3DList, VirtualEulerList, VirtualFloatList, VirtualDoubleList,
    Action, ActionEvaluator, PathIndexActionChannel,
    BoundedAction, BoundedActionEvaluator,Color,
    ColorList, PolygonIndicesList, IntegerList, PolySpline, BezierSpline, Interpolation
)
from ... math cimport (
    add, subtract, multiply, divide_Save, modulo_Save,
    sin, cos, tan, asin_Save, acos_Save, atan, atan2, hypot,
    power_Save, floor, ceil, sqrt_Save, invert, reciprocal_Save,
    snap_Save, copySign, floorDivision_Save, logarithm_Save,
    Vector3, Euler3, Matrix4, toMatrix4,toVector3,multMatrix4, toPyMatrix4,
    invertOrthogonalTransformation,setTranslationRotationScaleMatrix,
    setRotationXMatrix, setRotationYMatrix, setRotationZMatrix,
    setRotationMatrix, setTranslationMatrix, setIdentityMatrix,
    setScaleMatrix,setMatrixTranslation,transposeMatrix_Inplace
)

####################################    Color Functions    ##############################################
 
def getTextureColors_moded(texture, Vector3DList locations, float multiplier):
    cdef long amount = locations.length
    cdef DoubleList reds = DoubleList(length = amount)
    cdef DoubleList greens = DoubleList(length = amount)
    cdef DoubleList blues = DoubleList(length = amount)
    cdef DoubleList alphas = DoubleList(length = amount)
    cdef ColorList colors = ColorList(length = amount)
    cdef float r, g, b, a

    for i in range(amount):
        r, g, b, a = texture.evaluate(locations[i])
        reds.data[i] = r*multiplier
        greens.data[i] = g*multiplier
        blues.data[i] = b*multiplier
        alphas.data[i] = a*multiplier
        colors.data[i] = Color(r, g, b, a)

    return colors, reds, greens, blues, alphas

def getTexturegreys(texture, Vector3DList locations, float multiplier):
    cdef long amount = locations.length
    cdef DoubleList greys = DoubleList(length = amount)
    cdef float r, g, b, a

    for i in range(amount):
        r, g, b, a = texture.evaluate(locations[i])
        greys.data[i] = ((r+g+b)/3)*multiplier

    return greys 

def generateRandomColors(Py_ssize_t count, Py_ssize_t seed, float scale, bint normalized):
    cdef Py_ssize_t i
    cdef Vector3DList randomVectors = generateRandomVectors(seed, count, scale, normalized)
    cdef ColorList colors = ColorList(length = count)

    for i in range(count):
        r = absNumber(randomVectors.data[i].x)
        g = absNumber(randomVectors.data[i].y)
        b = absNumber(randomVectors.data[i].z)
        colors.data[i] = Color(r, g, b, 1)

    return colors

####################################    Rotation Functions    ##############################################

def quaternionsToEulers(QuaternionList q):
    return Matrix4x4List.toEulers(quaternionsToMatrices(q))

def quaternionsToMatrices(QuaternionList q):
    cdef Py_ssize_t count = len(q)
    cdef Matrix4x4List m = Matrix4x4List(length = count)
    cdef double sqw, sqx, sqy, sqz, invs, tmp1, tmp2

    for i in range(count):
        sqw = q.data[i].w * q.data[i].w
        sqx = q.data[i].x * q.data[i].x
        sqy = q.data[i].y * q.data[i].y
        sqz = q.data[i].z * q.data[i].z
        invs = 1 / (sqx + sqy + sqz + sqw)

        m.data[i].a11 = ( sqx - sqy - sqz + sqw)*invs
        m.data[i].a22 = (-sqx + sqy - sqz + sqw)*invs
        m.data[i].a33 = (-sqx - sqy + sqz + sqw)*invs

        tmp1 = q.data[i].x * q.data[i].y
        tmp2 = q.data[i].z * q.data[i].w
        m.data[i].a21 = 2.0 * (tmp1 + tmp2)*invs
        m.data[i].a12 = 2.0 * (tmp1 - tmp2)*invs

        tmp1 = q.data[i].x * q.data[i].z
        tmp2 = q.data[i].y * q.data[i].w
        m.data[i].a31 = 2.0 * (tmp1 - tmp2)*invs
        m.data[i].a13 = 2.0 * (tmp1 + tmp2)*invs

        tmp1 = q.data[i].y * q.data[i].z
        tmp2 = q.data[i].x * q.data[i].w
        m.data[i].a32 = 2.0 * (tmp1 + tmp2)*invs
        m.data[i].a23 = 2.0 * (tmp1 - tmp2)*invs

        m.data[i].a14 = m.data[i].a24 = m.data[i].a34 = 0
        m.data[i].a41 = m.data[i].a42 = m.data[i].a43 = 0
        m.data[i].a44 = 1

    return m

####################################    Lerp Functions    ##############################################

def euler_lerp(EulerList eA, EulerList eB, DoubleList influences):
    cdef Py_ssize_t count = max(eA.getLength(), eB.getLength())
    cdef Py_ssize_t i
    cdef EulerList out_eulerlist = EulerList(length = count)

    for i in range(count):
        out_eulerlist.data[i].x = eA.data[i].x * (1-influences.data[i]) + eB.data[i].x * influences.data[i]
        out_eulerlist.data[i].y = eA.data[i].y * (1-influences.data[i]) + eB.data[i].y * influences.data[i]
        out_eulerlist.data[i].z = eA.data[i].z * (1-influences.data[i]) + eB.data[i].z * influences.data[i]
        out_eulerlist.data[i].order = eA.data[i].order

    return out_eulerlist 

def quaternion_lerp(QuaternionList qA, QuaternionList qB, DoubleList influences):
    cdef Py_ssize_t count = len(qA)
    cdef QuaternionList out_Quat = QuaternionList(length = count)
    cdef double t, t1, dot, w1, w2, x1, x2, y1, y2, z1, z2, ls, invNorm

    for i in range(count):
        t = influences.data[i]
        t1 = 1 - t
        w1, w2 = qA.data[i].w, qB.data[i].w
        x1, x2 = qA.data[i].x, qB.data[i].x
        y1, y2 = qA.data[i].y, qB.data[i].y
        z1, z2 = qA.data[i].z, qB.data[i].z

        dot = x1 * x2 + y1 * y2 + z1 * z2 + w1 * w2

        if dot >= 0:
            out_Quat.data[i].w = t1 * w1 + t * w2
            out_Quat.data[i].x = t1 * x1 + t * x2
            out_Quat.data[i].y = t1 * y1 + t * y2
            out_Quat.data[i].z = t1 * z1 + t * z2
        else:
            out_Quat.data[i].w = t1 * w1 - t * w2
            out_Quat.data[i].x = t1 * x1 - t * x2
            out_Quat.data[i].y = t1 * y1 - t * y2
            out_Quat.data[i].z = t1 * z1 - t * z2

        ls = out_Quat.data[i].w * out_Quat.data[i].w
        ls += out_Quat.data[i].x * out_Quat.data[i].x
        ls += out_Quat.data[i].y * out_Quat.data[i].y
        ls += out_Quat.data[i].z * out_Quat.data[i].z     
        invNorm = 1/sqrt(ls)
        out_Quat.data[i].w *= invNorm
        out_Quat.data[i].x *= invNorm
        out_Quat.data[i].y *= invNorm
        out_Quat.data[i].z *= invNorm

    return out_Quat


def vector_lerp(Vector3DList vA, Vector3DList vB, DoubleList influences):
    cdef Py_ssize_t count = max(vA.getLength(), vB.getLength())
    cdef Py_ssize_t i
    cdef Vector3DList out_vectorlist = Vector3DList(length = count)

    for i in range(count):
        out_vectorlist.data[i].x = vA.data[i].x * (1-influences.data[i]) + vB.data[i].x * influences.data[i]
        out_vectorlist.data[i].y = vA.data[i].y * (1-influences.data[i]) + vB.data[i].y * influences.data[i]
        out_vectorlist.data[i].z = vA.data[i].z * (1-influences.data[i]) + vB.data[i].z * influences.data[i]

    return out_vectorlist

def matrix_lerp(Matrix4x4List mA, Matrix4x4List mB, DoubleList influences):
    cdef Matrix4x4List m = matrix_lerp_skew(mA, mB, influences)
    cdef Vector3DList s = vector_lerp(extractMatrixScales(mA), extractMatrixScales(mB), influences)
    cdef VirtualVector3DList translations_out = VirtualVector3DList.create(extractMatrixTranslations(m), (0, 0, 0))
    cdef VirtualEulerList rotations_out = VirtualEulerList.create(extractMatrixRotations(m), (0, 0, 0))
    cdef VirtualVector3DList scales_out = VirtualVector3DList.create(s, (1, 1, 1))

    return composeMatrices(len(mA), translations_out, rotations_out, scales_out)    

def matrix_lerp_skew(Matrix4x4List matrix1, Matrix4x4List matrix2, DoubleList influences): # scale skewing issue
    cdef Py_ssize_t count = len(matrix1)
    cdef Matrix4x4List out_matrixList = Matrix4x4List(length = count)

    for i in range(count):
        out_matrixList.data[i].a11 = matrix1.data[i].a11 + (matrix2.data[i].a11 - matrix1.data[i].a11) * influences.data[i]
        out_matrixList.data[i].a12 = matrix1.data[i].a12 + (matrix2.data[i].a12 - matrix1.data[i].a12) * influences.data[i]
        out_matrixList.data[i].a13 = matrix1.data[i].a13 + (matrix2.data[i].a13 - matrix1.data[i].a13) * influences.data[i]
        out_matrixList.data[i].a14 = matrix1.data[i].a14 + (matrix2.data[i].a14 - matrix1.data[i].a14) * influences.data[i]

        out_matrixList.data[i].a21 = matrix1.data[i].a21 + (matrix2.data[i].a21 - matrix1.data[i].a21) * influences.data[i]
        out_matrixList.data[i].a22 = matrix1.data[i].a22 + (matrix2.data[i].a22 - matrix1.data[i].a22) * influences.data[i]
        out_matrixList.data[i].a23 = matrix1.data[i].a23 + (matrix2.data[i].a23 - matrix1.data[i].a23) * influences.data[i]
        out_matrixList.data[i].a24 = matrix1.data[i].a24 + (matrix2.data[i].a24 - matrix1.data[i].a24) * influences.data[i]

        out_matrixList.data[i].a31 = matrix1.data[i].a31 + (matrix2.data[i].a31 - matrix1.data[i].a31) * influences.data[i]
        out_matrixList.data[i].a32 = matrix1.data[i].a32 + (matrix2.data[i].a32 - matrix1.data[i].a32) * influences.data[i]
        out_matrixList.data[i].a33 = matrix1.data[i].a33 + (matrix2.data[i].a33 - matrix1.data[i].a33) * influences.data[i]
        out_matrixList.data[i].a34 = matrix1.data[i].a34 + (matrix2.data[i].a34 - matrix1.data[i].a34) * influences.data[i]

        out_matrixList.data[i].a41 = matrix1.data[i].a41 + (matrix2.data[i].a41 - matrix1.data[i].a41) * influences.data[i]
        out_matrixList.data[i].a42 = matrix1.data[i].a42 + (matrix2.data[i].a42 - matrix1.data[i].a42) * influences.data[i]
        out_matrixList.data[i].a43 = matrix1.data[i].a43 + (matrix2.data[i].a43 - matrix1.data[i].a43) * influences.data[i]
        out_matrixList.data[i].a44 = matrix1.data[i].a44 + (matrix2.data[i].a44 - matrix1.data[i].a44) * influences.data[i]

    return out_matrixList

####################################    Effector Functions    ##############################################

def offsetMatrices(Matrix4x4List matrices, Vector3DList v, EulerList e, Vector3DList s, DoubleList influences):
    cdef Vector3DList tA = extractMatrixTranslations(matrices)
    cdef EulerList rA = extractMatrixRotations(matrices)
    cdef Vector3DList sA = extractMatrixScales(matrices)
    cdef int count = matrices.getLength()
    cdef VirtualVector3DList translations_out = VirtualVector3DList.create(tA, (0, 0, 0))
    cdef VirtualEulerList rotations_out = VirtualEulerList.create(rA, (0, 0, 0))
    cdef VirtualVector3DList scales_out = VirtualVector3DList.create(sA, (1, 1, 1))

    for i in range(count):
        translations_out.get(i).x = tA.data[i].x + influences.data[i] * v.data[0].x
        translations_out.get(i).y = tA.data[i].y + influences.data[i] * v.data[0].y
        translations_out.get(i).z = tA.data[i].z + influences.data[i] * v.data[0].z
        rotations_out.get(i).x = rA.data[i].x + influences.data[i] * e.data[0].x
        rotations_out.get(i).y = rA.data[i].y + influences.data[i] * e.data[0].y
        rotations_out.get(i).z = rA.data[i].z + influences.data[i] * e.data[0].z
        scales_out.get(i).x = sA.data[i].x + influences.data[i] * s.data[0].x
        scales_out.get(i).y = sA.data[i].y + influences.data[i] * s.data[0].y
        scales_out.get(i).z = sA.data[i].z + influences.data[i] * s.data[0].z

    return composeMatrices(count, translations_out, rotations_out, scales_out)

def inheritanceCurveVector(Vector3DList vA, Vector3DList vB, Vector3DList splinePoints, float randomScale, DoubleList influences):
    cdef Py_ssize_t i, j, bIndex, aIndex
    cdef Py_ssize_t count = vA.getLength()
    cdef Py_ssize_t splinePointCount = splinePoints.getLength()
    cdef Py_ssize_t innerLength = splinePointCount + 2
    cdef double f, influence
    cdef Vector3DList out_vectorlist = Vector3DList(length = count)
    cdef Vector3DList innerVectorList = Vector3DList(length = innerLength)
    cdef Vector3DList randomVectors = generateRandomVectors(1, count, randomScale, False)

    for i in range(count):
        innerVectorList.data[0] = vA.data[i]

        for j in range(splinePointCount):
            innerVectorList.data[j+1].x = splinePoints.data[j].x + randomVectors.data[i].x
            innerVectorList.data[j+1].y = splinePoints.data[j].y + randomVectors.data[i].y
            innerVectorList.data[j+1].z = splinePoints.data[j].z + randomVectors.data[i].z

        innerVectorList.data[innerLength - 1] = vB.data[i]
        f = influences.data[i] * (innerLength - 1)
        influence = f % 1 
        bIndex = int(max(min(floor(f), innerLength - 1), 0))
        aIndex = int(max(min(ceil(f), innerLength - 1), 0))

        out_vectorlist.data[i].x = innerVectorList.data[bIndex].x * (1-influence) + innerVectorList.data[aIndex].x * influence
        out_vectorlist.data[i].y = innerVectorList.data[bIndex].y * (1-influence) + innerVectorList.data[aIndex].y * influence
        out_vectorlist.data[i].z = innerVectorList.data[bIndex].z * (1-influence) + innerVectorList.data[aIndex].z * influence

    return out_vectorlist

def inheritanceCurveEuler(QuaternionList qA, QuaternionList qB, QuaternionList splineRotations, DoubleList influences):
    cdef Py_ssize_t i, j, bIndex, aIndex
    cdef Py_ssize_t count = qA.getLength()
    cdef Py_ssize_t splineEulerCount = splineRotations.getLength()
    cdef Py_ssize_t innerLength = splineEulerCount + 2
    cdef double f, influence, t1, w, x, y, z, ls, invNorm
    cdef QuaternionList outEulerlist = QuaternionList(length = count)
    cdef QuaternionList inList = QuaternionList(length = innerLength)

    for i in range(count):
        inList.data[0] = qA.data[i]

        for j in range(splineEulerCount):
            inList.data[j+1].w = splineRotations.data[j].w
            inList.data[j+1].x = splineRotations.data[j].x
            inList.data[j+1].y = splineRotations.data[j].y
            inList.data[j+1].z = splineRotations.data[j].z

        inList.data[innerLength - 1] = qB.data[i]
        f = influences.data[i] * (innerLength - 1)
        influence = f % 1 
        bIndex = int(max(min(floor(f), innerLength - 1), 0))
        aIndex = int(max(min(ceil(f), innerLength - 1), 0))
        t1 = 1 - influence
        dot = inList.data[bIndex].x * inList.data[aIndex].x + inList.data[bIndex].y * inList.data[aIndex].y + inList.data[bIndex].z * inList.data[aIndex].z + inList.data[bIndex].w * inList.data[aIndex].w

        if dot >= 0:
            w = t1 * inList.data[bIndex].w + influence * inList.data[aIndex].w
            x = t1 * inList.data[bIndex].x + influence * inList.data[aIndex].x
            y = t1 * inList.data[bIndex].y + influence * inList.data[aIndex].y
            z = t1 * inList.data[bIndex].z + influence * inList.data[aIndex].z
        else:
            w = t1 * inList.data[bIndex].w - influence * inList.data[aIndex].w
            x = t1 * inList.data[bIndex].x - influence * inList.data[aIndex].x
            y = t1 * inList.data[bIndex].y - influence * inList.data[aIndex].y
            z = t1 * inList.data[bIndex].z - influence * inList.data[aIndex].z

        ls = w * w + x * x + y * y + z * z

        invNorm = 1/sqrt(ls)
        w *= invNorm
        x *= invNorm
        y *= invNorm
        z *= invNorm

        outEulerlist.data[i].w, outEulerlist.data[i].x, outEulerlist.data[i].y, outEulerlist.data[i].z = w, x, y, z

    return quaternionsToEulers(outEulerlist)

def inheritanceCurveMatrix(Matrix4x4List mA, Matrix4x4List mB, Vector3DList splinePoints, Matrix4x4List splineRotations, float randomScale, DoubleList influences, bint align):
    cdef Vector3DList t = inheritanceCurveVector(extractMatrixTranslations(mA), extractMatrixTranslations(mB), splinePoints, randomScale, influences)
    cdef EulerList r = quaternionsToEulers(quaternion_lerp(Matrix4x4List.toQuaternions(mA), Matrix4x4List.toQuaternions(mB), influences))
    if align:
        r = inheritanceCurveEuler(Matrix4x4List.toQuaternions(mA), Matrix4x4List.toQuaternions(mB), Matrix4x4List.toQuaternions(splineRotations), influences)
    cdef Vector3DList s = vector_lerp(extractMatrixScales(mA), extractMatrixScales(mB), influences) 

    cdef VirtualVector3DList translations_out = VirtualVector3DList.create(t, (0, 0, 0)) 
    cdef VirtualEulerList rotations_out = VirtualEulerList.create(r, (0, 0, 0))   
    cdef VirtualVector3DList scales_out = VirtualVector3DList.create(s, (1, 1, 1))

    return composeMatrices(len(mA), translations_out, rotations_out, scales_out)

####################################    Curl Noise Functions    ##############################################

#Curl reference: https://github.com/cabbibo/glsl-curl-noise
@cython.cdivision(True)
def curlNoise(Vector3DList vectorsIn, str noiseType, str fractalType, str perturbType, float epsilon, 
        Py_ssize_t seed, Py_ssize_t octaves, float amplitude, float frequency, scale, offset, bint normalize):
    cdef:
        Py_ssize_t i
        Py_ssize_t count = vectorsIn.getLength()
        Py_ssize_t countBig = count * 6
        double divisor, vecLen
        FloatList x, y, z
        Vector3DList px0, px1, py0, py1, pz0, pz1 
        Vector3DList curlyNoise = Vector3DList(length = count)
        Vector3DList bigList_x = Vector3DList(length = countBig)
        Vector3DList bigList_y = Vector3DList(length = countBig)
        Vector3DList bigList_z = Vector3DList(length = countBig)
        Vector3DList evaluatedList = Vector3DList(length = countBig)

    noise = PyNoise()
    noise.setNoiseType(noiseType)
    noise.setFractalType(fractalType)
    noise.setPerturbType(perturbType)
    noise.setAmplitude(amplitude)
    noise.setFrequency(frequency)
    noise.setOffset(offset)
    noise.setSeed(seed)
    noise.setAxisScales((scale.x, scale.y, scale.z))
    noise.setOctaves(min(max(octaves, 1), 10))
    noise.setCellularJitter(0)

    for i in range(count):
        bigList_x.data[i].x = vectorsIn.data[i].x - epsilon
        bigList_x.data[i].y = vectorsIn.data[i].y
        bigList_x.data[i].z = vectorsIn.data[i].z
        bigList_x.data[i+count].x = vectorsIn.data[i].x + epsilon
        bigList_x.data[i+count].y = vectorsIn.data[i].y
        bigList_x.data[i+count].z = vectorsIn.data[i].z
        bigList_x.data[i+count*2].x = vectorsIn.data[i].x
        bigList_x.data[i+count*2].y = vectorsIn.data[i].y - epsilon
        bigList_x.data[i+count*2].z = vectorsIn.data[i].z
        bigList_x.data[i+count*3].x = vectorsIn.data[i].x
        bigList_x.data[i+count*3].y = vectorsIn.data[i].y + epsilon
        bigList_x.data[i+count*3].z = vectorsIn.data[i].z
        bigList_x.data[i+count*4].x = vectorsIn.data[i].x
        bigList_x.data[i+count*4].y = vectorsIn.data[i].y
        bigList_x.data[i+count*4].z = vectorsIn.data[i].z - epsilon
        bigList_x.data[i+count*5].x = vectorsIn.data[i].x
        bigList_x.data[i+count*5].y = vectorsIn.data[i].y
        bigList_x.data[i+count*5].z = vectorsIn.data[i].z + epsilon

    for i in range(countBig):
        bigList_y.data[i].x = bigList_x.data[i].y - 19.1
        bigList_y.data[i].y = bigList_x.data[i].z + 33.4
        bigList_y.data[i].z = bigList_x.data[i].x + 47.2
        bigList_z.data[i].x = bigList_x.data[i].z + 74.2
        bigList_z.data[i].y = bigList_x.data[i].x - 124.5
        bigList_z.data[i].z = bigList_x.data[i].y + 99.4  

    x = noise.calculateList(bigList_x)
    y = noise.calculateList(bigList_y)
    z = noise.calculateList(bigList_z)

    for i in range(countBig):
        evaluatedList.data[i].x = x.data[i]
        evaluatedList.data[i].y = y.data[i]
        evaluatedList.data[i].z = z.data[i]

    px0 = evaluatedList[:count]
    px1 = evaluatedList[count:count*2]
    py0 = evaluatedList[count*2:count*3]
    py1 = evaluatedList[count*3:count*4]
    pz0 = evaluatedList[count*4:count*5]
    pz1 = evaluatedList[count*5:count*6]

    divisor = 1.0 /2.0 * epsilon

    for i in range(count):
        curlyNoise.data[i].x = (py1.data[i].z - py0.data[i].z - pz1.data[i].y + pz0.data[i].y) * divisor
        curlyNoise.data[i].y = (pz1.data[i].x - pz0.data[i].x - px1.data[i].z + px0.data[i].z) * divisor
        curlyNoise.data[i].z = (px1.data[i].y - px0.data[i].y - py1.data[i].x + py0.data[i].x) * divisor

        if normalize:
            Vector3DList.normalize(curlyNoise)

    return curlyNoise

def EulerIntegrateCurl(Vector3DList vectors, str noiseType, str fractalType, str perturbType, float epsilon, 
    Py_ssize_t seed, Py_ssize_t octaves, float amplitude, float frequency, scale, offset, bint normalize, Py_ssize_t iteration, bint fullList):
    cdef Py_ssize_t i
    cdef Vector3DList result, fullResult
    result = vectors.copy()
    fullResult = vectors.copy()

    for i in range(iteration):
        if i != 0:
            result = vectorListADD(curlNoise(result, noiseType, fractalType, perturbType, epsilon, 
                    seed, octaves, amplitude, frequency, scale, offset, normalize), result)
            if fullList:
                fullResult.extend(result)

    if fullList:
        return fullResult
    else:
        return result

cdef Vector3DList vectorListADD(Vector3DList a, Vector3DList b):
    cdef Py_ssize_t i
    for i in range(a.getLength()):
        a.data[i].x += b.data[i].x
        a.data[i].y += b.data[i].y
        a.data[i].z += b.data[i].z

    return a         
               