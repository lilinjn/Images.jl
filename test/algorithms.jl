import Images
using Color, Base.Test

# Comparison of each element in arrays with a scalar
approx_equal(ar, v) = all(abs(ar.-v) .< sqrt(eps(v)))
approx_equal(ar::Images.AbstractImage, v) = approx_equal(Images.data(ar), v)

# arithmetic
img = convert(Images.Image, zeros(3,3))
@assert Images.limits(img) == (0,1)
img2 = (img .+ 3)/2
@assert all(img2 .== 1.5)
@assert Images.limits(img2) == (1.5,2.0)
img3 = 2img2
@assert all(img3 .== 3)
img3 = copy(img2)
img3[img2 .< 4] = -1
@assert all(img3 .== -1)
img = convert(Images.Image, rand(3,4))
A = rand(3,4)
img2 = img .* A
@assert all(Images.data(img2) == Images.data(img).*A)
@assert Images.limits(img2) == (0,1)
img2 = convert(Images.Image, A)
img2 = img2 .- 0.5
img3 = 2img .* img2
@assert Images.limits(img3) == (-1, 1)
img2 = img ./ A
@assert Images.limits(img2) == (0, Inf)
img2 = (2img).^2
@assert Images.limits(img2) == (0, 4)
imgu = convert(Images.Image, Uint8[1 240; 10 128])  # from #101
@assert Images.limits(2imgu) == (0x00,0xff)

# scaling, ssd
img = convert(Images.Image, fill(typemax(Uint16), 3, 3))
scalei = Images.scaleinfo(Uint8, img)
img8 = scale(scalei, img)
@assert all(img8 .== typemax(Uint8))
mxA = -1.0
while mxA < 0
    A = randn(3,3)
    mxA = maximum(A)
end
offset = 30.0
img = convert(Images.Image, A .+ offset)
scalei = Images.ScaleMinMax{Uint8, Float64}(offset, offset+mxA, 100/mxA)
imgs = scale(scalei, img)
@assert minimum(imgs) == 0
@assert maximum(imgs) == 100
@assert eltype(imgs) == Uint8
imgs = Images.imadjustintensity(img, [])
mnA = minimum(A)
@assert Images.ssd(imgs, (A.-mnA)/(mxA-mnA)) < eps()
A = reshape(1:9, 3, 3)
B = scale(Images.ClipMin(Float32, 3), A)
@assert eltype(B) == Float32 && B == [3 4 7; 3 5 8; 3 6 9]
B = scale(Images.ClipMax(Uint8, 7), A)
@assert eltype(B) == Uint8 && B == [1 4 7; 2 5 7; 3 6 7]

# Reductions
let
    A = rand(5,5,3)
    img = Images.colorim(A, "RGB")
    img["limits"] = (0.0, 1.0)
    s12 = sum(img, (1,2))
    @test colorspace(s12) == "RGB"
    @test limits(s12) == (0.0,25.0)
    s3 = sum(img, (3,))
    @test colorspace(s3) == "Unknown"
    @test limits(s3) == (0.0,3.0)
end

# Array padding
let A = [1 2; 3 4]
    @test Images.padarray(A, (0,0), (0,0), "replicate") == A
    @test Images.padarray(A, (1,2), (2,0), "replicate") == [1 1 1 2; 1 1 1 2; 3 3 3 4; 3 3 3 4; 3 3 3 4]
    @test Images.padarray(A, [2,1], [0,2], "circular") == [2 1 2 1 2; 4 3 4 3 4; 2 1 2 1 2; 4 3 4 3 4]
    @test Images.padarray(A, (1,2), (2,0), "symmetric") == [2 1 1 2; 2 1 1 2; 4 3 3 4; 4 3 3 4; 2 1 1 2]
    @test Images.padarray(A, (1,2), (2,0), "value", -1) == [-1 -1 -1 -1; -1 -1 1 2; -1 -1 3 4; -1 -1 -1 -1; -1 -1 -1 -1]
    A = [1 2 3; 4 5 6]
    @test Images.padarray(A, (1,2), (2,0), "reflect") == [6 5 4 5 6; 3 2 1 2 3; 6 5 4 5 6; 3 2 1 2 3; 6 5 4 5 6]
    A = [1 2; 3 4]
    @test Images.padarray(A, (1,1)) == [1 1 2 2; 1 1 2 2; 3 3 4 4; 3 3 4 4]
    @test Images.padarray(A, (1,1), "replicate", "both") == [1 1 2 2; 1 1 2 2; 3 3 4 4; 3 3 4 4]
    @test Images.padarray(A, (1,1), "circular", "pre") == [4 3 4; 2 1 2; 4 3 4]
    @test Images.padarray(A, (1,1), "symmetric", "post") == [1 2 2; 3 4 4; 3 4 4]
    A = ["a" "b"; "c" "d"]
    @test Images.padarray(A, (1,1)) == ["a" "a" "b" "b"; "a" "a" "b" "b"; "c" "c" "d" "d"; "c" "c" "d" "d"]
end

# filtering
EPS = 1e-14
for T in (Float64, Int)
    A = zeros(T,3,3); A[2,2] = 1
    kern = rand(3,3)
    @test maximum(abs(Images.imfilter(A, kern) - rot180(kern))) < EPS
    kern = rand(2,3)
    @test maximum(abs(Images.imfilter(A, kern)[1:2,:] - rot180(kern))) < EPS
    kern = rand(3,2)
    @test maximum(abs(Images.imfilter(A, kern)[:,1:2] - rot180(kern))) < EPS
end
for T in (Float64, Int)
    # Separable kernels
    A = zeros(T,3,3); A[2,2] = 1
    kern = rand(3).*rand(3)'
    @test maximum(abs(Images.imfilter(A, kern) - rot180(kern))) < EPS
    kern = rand(2).*rand(3)'
    @test maximum(abs(Images.imfilter(A, kern)[1:2,:] - rot180(kern))) < EPS
    kern = rand(3).*rand(2)'
    @test maximum(abs(Images.imfilter(A, kern)[:,1:2] - rot180(kern))) < EPS
end
A = zeros(3,3); A[2,2] = 1
kern = rand(3,3)
@test maximum(abs(Images.imfilter_fft(A, kern) - rot180(kern))) < EPS
kern = rand(2,3)
@test maximum(abs(Images.imfilter_fft(A, kern)[1:2,:] - rot180(kern))) < EPS
kern = rand(3,2)
@test maximum(abs(Images.imfilter_fft(A, kern)[:,1:2] - rot180(kern))) < EPS

@assert approx_equal(Images.imfilter(ones(4,4), ones(3,3)), 9.0)
@assert approx_equal(Images.imfilter(ones(3,3), ones(3,3)), 9.0)
@assert approx_equal(Images.imfilter(ones(3,3), [1 1 1;1 0.0 1;1 1 1]), 8.0)
img = convert(Images.Image, ones(4,4))
@assert approx_equal(Images.imfilter(img, ones(3,3)), 9.0)
A = zeros(5,5,3); A[3,3,[1,3]] = 1
@assert Images.colordim(A) == 3
kern = rand(3,3)
kernpad = zeros(5,5); kernpad[2:4,2:4] = kern
Af = Images.imfilter(A, kern)

@test_approx_eq Af cat(3, rot180(kernpad), zeros(5,5), rot180(kernpad))
Aimg = permutedims(convert(Images.Image, A), [3,1,2])
@test_approx_eq Images.imfilter(Aimg, kern) permutedims(Af, [3,1,2])
@assert approx_equal(Images.imfilter(ones(4,4),ones(1,3),"replicate"), 3.0)

@assert approx_equal(Images.imfilter_gaussian(ones(4,4), [5,5]), 1.0)

A = zeros(Int, 9, 9); A[5, 5] = 1
@test maximum(abs(Images.imfilter_LoG(A, [1,1]) - imlog(1.0))) < EPS

# restriction
A = reshape(uint16(1:60), 4, 5, 3)
B = Images.restrict(A, (1,2))
@test_approx_eq B cat(3, [ 0.96875  4.625   5.96875;
                           2.875   10.5    12.875;
                           1.90625  5.875   6.90625],
                         [ 8.46875  14.625 13.46875;
                          17.875    30.5   27.875;
                           9.40625  15.875 14.40625],
                         [15.96875  24.625 20.96875;
                          32.875    50.5   42.875;
                          16.90625  25.875 21.90625])
A = reshape(1:60, 5, 4, 3)
B = Images.restrict(A, (1,2,3))
@test_approx_eq B cat(3, [ 2.6015625  8.71875 6.1171875;
                           4.09375   12.875   8.78125;
                           3.5390625 10.59375 7.0546875],
                         [10.1015625 23.71875 13.6171875;
                          14.09375   32.875   18.78125;
                          11.0390625 25.59375 14.5546875])

# color conversion
gray = linspace(0.0,1.0,5) # a 1-dimensional image
gray8 = iround(Uint8, 255*gray)
gray32 = [uint32(g)<<16 | uint32(g)<<8 | uint32(g) for g in gray8]
imgray = Images.Image(gray, ["colordim"=>0, "colorspace"=>"Gray"])
buf = Images.uint32color(imgray)
@assert buf == gray32
rgb = [RGB(g, g, g) for g in gray]
buf = Images.uint32color(rgb)
@assert buf == gray32
img = Images.Image(gray32, ["colordim"=>0, "colorspace"=>"RGB24"])
buf = Images.uint32color(img)
@assert buf == gray32
rgb = repeat(gray, outer=[1,3])
img = Images.Image(rgb, ["colordim"=>2, "colorspace"=>"RGB"])
buf = Images.uint32color(img)
@assert buf == gray32
rgb = repeat(gray', outer=[3,1])
img = Images.Image(rgb, ["colordim"=>1, "colorspace"=>"RGB"])
buf = Images.uint32color(img)
@assert buf == gray32
ovr = Images.Overlay((gray, 0*gray), (RGB(1,0,1), RGB(0,1,0)), ((0,1),(0,1)))
buf = Images.uint32color(ovr)
nogreen = [uint32(g)<<16 | uint32(g) for g in gray8]
@assert buf == nogreen
ovr = Images.Overlay((gray, gray), (RGB(1,0,1), RGB(0,1,0)), ((0,1),(0,1)))
ovr.visible[2] = false
buf = Images.uint32color(ovr)
@assert buf == nogreen

# erode/dilate
A = zeros(4,4,3)
A[2,2,1] = 0.8
A[4,4,2] = 0.6
Ae = Images.erode(A)
@assert Ae == zeros(size(A))
Ad = Images.dilate(A)
Ar = [0.8 0.8 0.8 0;
      0.8 0.8 0.8 0;
      0.8 0.8 0.8 0;
      0 0 0 0]
Ag = [0 0 0 0;
      0 0 0 0;
      0 0 0.6 0.6;
      0 0 0.6 0.6]
@assert Ad == cat(3, Ar, Ag, zeros(4,4))
Ae = Images.erode(Ad)
Ar = [0.8 0.8 0 0;
      0.8 0.8 0 0;
      0 0 0 0;
      0 0 0 0]
Ag = [0 0 0 0;
      0 0 0 0;
      0 0 0 0;
      0 0 0 0.6]
@assert Ae == cat(3, Ar, Ag, zeros(4,4))

# opening/closing
A = zeros(4,4,3)
A[2,2,1] = 0.8
A[4,4,2] = 0.6
Ao = Images.opening(A)
@assert Ao == zeros(size(A))
A = zeros(10,10)
A[4:7,4:7] = 1
B = copy(A)
A[5,5] = 0
Ac = Images.closing(A)
@assert Ac == B

# label_components
A = [true  true  false true;
     true  false true  true]
lbltarget = [1 1 0 2;
             1 0 2 2]
lbltarget1 = [1 2 0 4;
              1 0 3 4]
@assert Images.label_components(A) == lbltarget
@assert Images.label_components(A, [1]) == lbltarget1
connectivity = [false true  false;
                true  false true;
                false true  false]
@assert Images.label_components(A, connectivity) == lbltarget
connectivity = trues(3,3)
lbltarget2 = [1 1 0 1;
              1 0 1 1]
@assert Images.label_components(A, connectivity) == lbltarget2

# phantoms

P = [ 0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0;
      0.0  0.0  1.0  0.2  0.2  1.0  0.0  0.0;
      0.0  0.0  0.2  0.3  0.3  0.2  0.0  0.0;
      0.0  0.0  0.2  0.0  0.2  0.2  0.0  0.0;
      0.0  0.0  0.2  0.0  0.0  0.2  0.0  0.0;
      0.0  0.0  0.2  0.2  0.2  0.2  0.0  0.0;
      0.0  0.0  1.0  0.2  0.2  1.0  0.0  0.0;
      0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0 ]

Q = Images.shepp_logan(8)
@assert norm((P-Q)[:]) < 1e-10

P = [ 0.0  0.0  0.0   0.0   0.0   0.0   0.0  0.0;
      0.0  0.0  2.0   1.02  1.02  2.0   0.0  0.0;
      0.0  0.0  1.02  1.03  1.03  1.02  0.0  0.0;
      0.0  0.0  1.02  1.0   1.02  1.02  0.0  0.0;
      0.0  0.0  1.02  1.0   1.0   1.02  0.0  0.0;
      0.0  0.0  1.02  1.02  1.02  1.02  0.0  0.0;
      0.0  0.0  2.0   1.02  1.02  2.0   0.0  0.0;
      0.0  0.0  0.0   0.0   0.0   0.0   0.0  0.0 ]

Q = Images.shepp_logan(8,highContrast=false)
@assert norm((P-Q)[:]) < 1e-10

## Checkerboard array, used to test image gradients

let
    white{T}(::Type{T}) = one(T)
    black{T}(::Type{T}) = zero(T)
    white{T<:Unsigned}(::Type{T}) = typemax(T)
    black{T<:Unsigned}(::Type{T}) = typemin(T)

    global checkerboard
    function checkerboard{T}(::Type{T}, sq_width::Integer, count::Integer)
        wh = fill(white(T), (sq_width,sq_width))
        bk = fill(black(T), (sq_width,sq_width))
        bw = [wh bk; bk wh]
        vert = repmat(bw, (count>>1), 1)
        isodd(count) && (vert = vcat(vert, [wh bk]))
        cb = repmat(vert, 1, (count>>1))
        isodd(count) && (cb = hcat(cb, vert[:,1:sq_width]))
        cb
    end

    checkerboard(sq_width::Integer, count::Integer) = checkerboard(Uint8, sq_width, count)
end

SZ=5

cb_array    = checkerboard(SZ,3)
cb_image_xy = grayim(cb_array)
cb_image_yx = grayim(cb_array)
cb_image_yx["spatialorder"] = ["y","x"]

for method in ["sobel", "prewitt", "ando3", "ando4", "ando5", "ando4_sep", "ando5_sep"]
    ## Checkerboard array

    (agx, agy) = imgradients(cb_array, method)
    amag = magnitude(agx, agy)
    agphase = phase(agx, agy)
    @assert (amag, agphase) == magnitude_phase(agx, agy)

    @assert agx[1,SZ]   < 0.0   # white to black transition
    @assert agx[1,2*SZ] > 0.0   # black to white transition
    @assert agy[SZ,1]   < 0.0   # white to black transition
    @assert agy[2*SZ,1] > 0.0   # black to white transition

    # Test direction of increasing gradient
    @assert cos(agphase[1,SZ])   - (-1.0) < EPS   # increasing left  (=  pi   radians)
    @assert cos(agphase[1,2*SZ]) -   1.0  < EPS   # increasing right (=   0   radians)
    @assert sin(agphase[SZ,1])   -   1.0  < EPS   # increasing up    (=  pi/2 radians)
    @assert sin(agphase[2*SZ,1]) - (-1.0) < EPS   # increasing down  (= -pi/2 radians)

    # Test that orientation is perpendicular to gradient
    aorient = orientation(agx, agy)
    @assert all((cos(agphase).*cos(aorient) .+ sin(agphase).*sin(aorient) .< EPS) |
                ((agphase .== 0.0) & (aorient .== 0.0)))  # this part is where both are 
                                                          # zero because there is no gradient

    ## Checkerboard Image with row major order

    (gx, gy) = imgradients(cb_image_xy, method)
    mag = magnitude(gx, gy)
    gphase = phase(gx, gy)
    @assert (mag, gphase) == magnitude_phase(gx, gy)

    @assert gx[SZ,1]   < 0.0   # white to black transition
    @assert gx[2*SZ,1] > 0.0   # black to white transition
    @assert gy[1,SZ]   < 0.0   # white to black transition
    @assert gy[1,2*SZ] > 0.0   # black to white transition

    @assert cos(gphase[SZ,1])   - (-1.0) < EPS   # increasing left  (=  pi   radians)
    @assert cos(gphase[2*SZ,1]) -   1.0  < EPS   # increasing right (=   0   radians)
    @assert sin(gphase[1,SZ])   -   1.0  < EPS   # increasing up    (=  pi/2 radians)
    @assert sin(gphase[1,2*SZ]) - (-1.0) < EPS   # increasing down  (= -pi/2 radians)

    # Test that orientation is perpendicular to gradient
    orient = orientation(gx, gy)
    @assert all((cos(gphase).*cos(orient) .+ sin(gphase).*sin(orient) .< EPS) |
                ((gphase .== 0.0) & (orient .== 0.0)))  # this part is where both are 
                                                        # zero because there is no gradient

    ## Checkerboard Image with column-major order

    (gx, gy) = imgradients(cb_image_yx, method)
    mag = magnitude(gx, gy)
    gphase = phase(gx, gy)
    @assert (mag, gphase) == magnitude_phase(gx, gy)

    @assert gx[1,SZ]   < 0.0   # white to black transition
    @assert gx[1,2*SZ] > 0.0   # black to white transition
    @assert gy[SZ,1]   < 0.0   # white to black transition
    @assert gy[2*SZ,1] > 0.0   # black to white transition

    # Test direction of increasing gradient
    @assert cos(gphase[1,SZ])   - (-1.0) < EPS   # increasing left  (=  pi   radians)
    @assert cos(gphase[1,2*SZ]) -   1.0  < EPS   # increasing right (=   0   radians)
    @assert sin(gphase[SZ,1])   -   1.0  < EPS   # increasing up    (=  pi/2 radians)
    @assert sin(gphase[2*SZ,1]) - (-1.0) < EPS   # increasing down  (= -pi/2 radians)

    # Test that orientation is perpendicular to gradient
    orient = orientation(gx, gy)
    @assert all((cos(gphase).*cos(orient) .+ sin(gphase).*sin(orient) .< EPS) |
                ((gphase .== 0.0) & (orient .== 0.0)))  # this part is where both are 
                                                        # zero because there is no gradient

end

# Create an image with white along diagonals -2:2 and black elsewhere
m = zeros(Uint8, 20,20)
for i = -2:2; m[diagind(m,i)] = 0xff; end

m_xy = grayim(m')
m_yx = grayim(m)
m_yx["spatialorder"] = ["y","x"]

for method in ["sobel", "prewitt", "ando3", "ando4", "ando5", "ando4_sep", "ando5_sep"]
    ## Diagonal array

    (agx, agy) = imgradients(m, method)
    amag = magnitude(agx, agy)
    agphase = phase(agx, agy)
    @assert (amag, agphase) == magnitude_phase(agx, agy)

    @assert agx[7,9]  < 0.0   # white to black transition
    @assert agx[10,8] > 0.0   # black to white transition
    @assert agy[10,8] < 0.0   # white to black transition
    @assert agy[7,9]  > 0.0   # black to white transition

    # Test direction of increasing gradient
    @assert abs(agphase[10,8] -    pi/4 ) < EPS   # lower edge (increasing up-right  =   pi/4 radians)
    @assert abs(agphase[7,9]  - (-3pi/4)) < EPS   # upper edge (increasing down-left = -3pi/4 radians)

    # Test that orientation is perpendicular to gradient
    aorient = orientation(agx, agy)
    @assert all((cos(agphase).*cos(aorient) .+ sin(agphase).*sin(aorient) .< EPS) |
                ((agphase .== 0.0) & (aorient .== 0.0)))  # this part is where both are 
                                                          # zero because there is no gradient

    ## Diagonal Image, row-major order

    (gx, gy) = imgradients(m_xy, method)
    mag = magnitude(gx, gy)
    gphase = phase(gx, gy)
    @assert (mag, gphase) == magnitude_phase(gx, gy)

    @assert gx[9,7]  < 0.0   # white to black transition
    @assert gx[8,10] > 0.0   # black to white transition
    @assert gy[8,10] < 0.0   # white to black transition
    @assert gy[9,7]  > 0.0   # black to white transition

    # Test direction of increasing gradient
    @assert abs(gphase[8,10] -    pi/4 ) < EPS   # lower edge (increasing up-right  =   pi/4 radians)
    @assert abs(gphase[9,7]  - (-3pi/4)) < EPS   # upper edge (increasing down-left = -3pi/4 radians)

    # Test that orientation is perpendicular to gradient
    orient = orientation(gx, gy)
    @assert all((cos(gphase).*cos(orient) .+ sin(gphase).*sin(orient) .< EPS) |
                ((gphase .== 0.0) & (orient .== 0.0)))  # this part is where both are 
                                                        # zero because there is no gradient

    ## Diagonal Image, column-major order

    (gx, gy) = imgradients(m_yx, method)
    mag = magnitude(gx, gy)
    gphase = phase(gx, gy)
    @assert (mag, gphase) == magnitude_phase(gx, gy)

    @assert gx[7,9]  < 0.0   # white to black transition
    @assert gx[10,8] > 0.0   # black to white transition
    @assert gy[10,8] < 0.0   # white to black transition
    @assert gy[7,9]  > 0.0   # black to white transition

    # Test direction of increasing gradient
    @assert abs(gphase[10,8] -    pi/4 ) < EPS   # lower edge (increasing up-right  =   pi/4 radians)
    @assert abs(gphase[7,9]  - (-3pi/4)) < EPS   # upper edge (increasing down-left = -3pi/4 radians)

    # Test that orientation is perpendicular to gradient
    orient = orientation(gx, gy)
    @assert all((cos(gphase).*cos(orient) .+ sin(gphase).*sin(orient) .< EPS) |
                ((gphase .== 0.0) & (orient .== 0.0)))  # this part is where both are 
                                                        # zero because there is no gradient
end

# Nonmaximal suppression

function thin_edges(img)
    # Get orientation
    gx,gy = imgradients(img)
    orient = phase(gx,gy)

    # Do NMS thinning
    thin_edges_nonmaxsup_subpix(img, orient, radius=1.35)
end


function nms_test_horiz_vert(img, which)
    ## which = :horizontal or :vertical

    # Do NMS thinning
    t,s = thin_edges(img)

    # Calc peak location by hand

    # Interpolate values 1.35 pixels left and right
    # Orientation is zero radians -> to the right
    v1 = 6 - 0.35   # slope on right is 1
    v2 = 5 - 0.35*2 # slope on left is 2
    c = 7.0         # peak value

    # solve v = a*r^2 + b*r + c
    a = (v1 + v2)/2 - c
    b = a + c - v2
    r = -b/2a

    @assert abs(r - 1/6) < EPS

    # Location and value at peak
    peakloc = r*1.35 + 3
    peakval = a*r^2 + b*r + c

    transposed = spatialorder(img)[1] == "x"
    horizontal = which == :horizontal

    test_axis1 = transposed $ !horizontal

    @assert test_axis1 ? all(t[:,[1,2,4,5]] .== 0) : all(t[[1,2,4,5],:] .== 0)
    @assert test_axis1 ? all(t[:,3]   .== peakval) : all(t[3,:]   .== peakval)
    @assert test_axis1 ? all(s[:,[1,2,4,5]] .== zero(Base.Graphics.Point)) :
                         all(s[[1,2,4,5],:] .== zero(Base.Graphics.Point))

    if transposed
        if which == :horizontal
            @assert     [pt.x for pt in s[:,3]]  == [1:5]
            @assert all([pt.y for pt in s[:,3]] .== peakloc)
        else
            @assert all([pt.x for pt in s[3,:]] .== peakloc)
            @assert     [pt.y for pt in s[3,:]]  == [1:5]
        end
    else
        if which == :horizontal
            @assert     [pt.x for pt in s[3,:]]  == [1:5]
            @assert all([pt.y for pt in s[3,:]] .== peakloc)
        else
            @assert all([pt.x for pt in s[:,3]] .== peakloc)
            @assert     [pt.y for pt in s[:,3]]  == [1:5]
        end
    end
end

# Test image: vertical edge
m = [3.0  5.0  7.0  6.0  5.0
     3.0  5.0  7.0  6.0  5.0
     3.0  5.0  7.0  6.0  5.0
     3.0  5.0  7.0  6.0  5.0
     3.0  5.0  7.0  6.0  5.0]

m_xy = grayim(m')
m_yx = grayim(m)
m_yx["spatialorder"] = ["y","x"]

nms_test_horiz_vert(m, :vertical)
nms_test_horiz_vert(m_xy, :vertical)
nms_test_horiz_vert(m_yx, :vertical)

# Test image: horizontal edge
m = m'
m_xy = grayim(m')
m_yx = grayim(m)
m_yx["spatialorder"] = ["y","x"]

nms_test_horiz_vert(m, :horizontal)
nms_test_horiz_vert(m_xy, :horizontal)
nms_test_horiz_vert(m_yx, :horizontal)


function nms_test_diagonal(img)
    # Do NMS thinning
    t,s = thin_edges(img)

    # Calc peak location by hand

    # Interpolate values 1.35 pixels up and left, down and right
    # using bilinear interpolation
    # Orientation is π/4 radians -> 45 degrees up
    fr = 1.35*cos(π/4)
    lower = (7 + fr*(6-7))
    upper = (6 + fr*(5-6))
    v1 = lower + fr*(upper-lower)

    lower = (7 + fr*(5-7))
    upper = (5 + fr*(3-5))
    v2 = lower + fr*(upper-lower)

    c = 7.0         # peak value

    # solve v = a*r^2 + b*r + c
    a = (v1 + v2)/2 - c
    b = a + c - v2
    r = -b/2a

    @assert (r - 1/6) < EPS

    transposed = spatialorder(img)[1] == "x"

    # Location and value at peak

    x_peak_offset, y_peak_offset = r*fr, -r*fr
    peakval = a*r^2 + b*r + c

    @assert all(diag(data(t))[2:4] .== peakval)  # Edge pixels aren't interpolated here
    @assert all(t - diagm(diag(data(t))) .== 0)

    diag_s = copy(s, diagm(diag(data(s))))
    @assert s == diag_s

    @assert all([pt.x for pt in diag(data(s))[2:4]] - ([2:4] + x_peak_offset) .< EPS)
    @assert all([pt.y for pt in diag(data(s))[2:4]] - ([2:4] + y_peak_offset) .< EPS)

end


# Test image: diagonal edge
m = [7.0  6.0  5.0  0.0  0.0
     5.0  7.0  6.0  5.0  0.0
     3.0  5.0  7.0  6.0  5.0
     0.0  3.0  5.0  7.0  6.0
     0.0  0.0  3.0  5.0  7.0]

m_xy = grayim(m')
m_yx = grayim(m)
m_yx["spatialorder"] = ["y","x"]

nms_test_diagonal(m)
nms_test_diagonal(m_xy)
nms_test_diagonal(m_yx)
