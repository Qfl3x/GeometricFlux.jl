using Flux: Dense

in_channel = 3
out_channel = 5
N = 4
adj = [0. 1. 0. 1.;
       1. 0. 1. 0.;
       0. 1. 0. 1.;
       1. 0. 1. 0.]


@testset "layer" begin
    @testset "GCNConv" begin
        X = rand(in_channel, N)
        @testset "layer with graph" begin
            gc = GCNConv(adj, in_channel=>out_channel)
            @test size(gc.weight) == (out_channel, in_channel)
            @test size(gc.bias) == (out_channel,)
            @test graph(gc.fg) === adj

            Y = gc(X)
            @test size(Y) == (out_channel, N)
            
            g = Zygote.gradient(() -> sum(gc(X)), params(gc))
            @test length(g.grads) == 2

            # Test with transposed features
            Xt = rand(N, in_channel)
            Y = gc(transpose(Xt))
            @test size(Y) == (out_channel, N)
        end

        @testset "layer without graph" begin
            gc = GCNConv(in_channel=>out_channel)
            @test size(gc.weight) == (out_channel, in_channel)
            @test size(gc.bias) == (out_channel,)
            @test !has_graph(gc.fg)

            fg = FeaturedGraph(adj, X)
            fg_ = gc(fg)
            @test size(node_feature(fg_)) == (out_channel, N)
            @test_throws AssertionError gc(X)

            g = Zygote.gradient(() -> sum(node_feature(gc(fg))), params(gc))
            @test length(g.grads) == 4

            # Test with transposed features
            Xt = rand(N, in_channel)
            fgt = FeaturedGraph(adj, transpose(Xt))
            fgt_ = gc(fgt)
            @test size(node_feature(fgt_)) == (out_channel, N)
        end
    end


    @testset "ChebConv" begin
        k = 6
        X = rand(in_channel, N)
        @testset "layer with graph" begin
            cc = ChebConv(adj, in_channel=>out_channel, k)
            @test size(cc.weight) == (out_channel, in_channel, k)
            @test size(cc.bias) == (out_channel,)
            @test graph(cc.fg) === adj
            @test cc.k == k
            @test cc.in_channel == in_channel
            @test cc.out_channel == out_channel

            Y = cc(X)
            @test size(Y) == (out_channel, N)

            g = Zygote.gradient(() -> sum(cc(X)), params(cc))
            @test length(g.grads) == 3

            # Test with transposed features
            Xt = rand(N, in_channel)
            Y = cc(transpose(Xt))
            @test size(Y) == (out_channel, N)
        end

        @testset "layer without graph" begin
            cc = ChebConv(in_channel=>out_channel, k)
            @test size(cc.weight) == (out_channel, in_channel, k)
            @test size(cc.bias) == (out_channel,)
            @test !has_graph(cc.fg)
            @test cc.k == k
            @test cc.in_channel == in_channel
            @test cc.out_channel == out_channel

            fg = FeaturedGraph(adj, X)
            fg_ = cc(fg)
            @test size(node_feature(fg_)) == (out_channel, N)
            @test_throws AssertionError cc(X)

            g = Zygote.gradient(() -> sum(node_feature(cc(fg))), params(cc))
            @test length(g.grads) == 4

            # Test with transposed features
            Xt = rand(N, in_channel)
            fgt = FeaturedGraph(adj, transpose(Xt))
            fgt_ = cc(fgt)
            @test size(node_feature(fgt_)) == (out_channel, N)
        end
    end

    @testset "GraphConv" begin
        @testset "layer with graph" begin
            gc = GraphConv(adj, in_channel=>out_channel)
            @test graph(gc.fg) == [[2,4], [1,3], [2,4], [1,3]]
            @test size(gc.weight1) == (out_channel, in_channel)
            @test size(gc.weight2) == (out_channel, in_channel)
            @test size(gc.bias) == (out_channel,)

            X = rand(in_channel, N)
            Y = gc(X)
            @test size(Y) == (out_channel, N)

            # Test that the gradient can be computed
            g = Zygote.gradient(() -> sum(gc(X)), params(gc))
            @test length(g.grads) == 5

            # Test with transposed features
            Xt = rand(N, in_channel)
            Y = gc(transpose(Xt))
            @test size(Y) == (out_channel, N)
        end

        @testset "layer without graph" begin
            gc = GraphConv(in_channel=>out_channel)
            @test size(gc.weight1) == (out_channel, in_channel)
            @test size(gc.weight2) == (out_channel, in_channel)
            @test size(gc.bias) == (out_channel,)


            X = rand(in_channel, N)
            fg = FeaturedGraph(adj, X)
            fg_ = gc(fg)
            @test size(node_feature(fg_)) == (out_channel, N)
            @test_throws AssertionError gc(X)

            g = Zygote.gradient(() -> sum(node_feature(gc(fg))), params(gc))
            @test length(g.grads) == 5

            # Test with transposed features
            Xt = rand(N, in_channel)
            fgt = FeaturedGraph(adj, transpose(Xt))
            fgt_ = gc(fgt)
            @test size(node_feature(fgt_)) == (out_channel, N)
        end
    end

    @testset "GATConv" begin
        X = rand(in_channel, N)

        @testset "layer with graph" begin
            @testset "concat=true" begin
                for heads = [1, 6]
                    gat = GATConv(adj, in_channel=>out_channel, heads=heads, concat=true)
                    @test graph(gat.fg) == [[2,4], [1,3], [2,4], [1,3]]
                    @test size(gat.weight) == (out_channel * heads, in_channel)
                    @test size(gat.bias) == (out_channel * heads,)
                    @test size(gat.a) == (2*out_channel, heads, 1)

                    Y = gat(X)
                    @test size(Y) == (out_channel * heads, N)

                    g = Zygote.gradient(() -> sum(gat(X)), params(gat))
                    @test length(g.grads) == 5

                    # Test with transposed features
                    Xt = rand(N, in_channel)
                    Y = gat(transpose(Xt))
                    @test size(Y) == (out_channel * heads, N)
                end
            end

            @testset "concat=false" begin
                for heads = [1, 6]
                    gat = GATConv(adj, in_channel=>out_channel, heads=heads, concat=false)
                    @test graph(gat.fg) == [[2,4], [1,3], [2,4], [1,3]]
                    @test size(gat.weight) == (out_channel * heads, in_channel)
                    @test size(gat.bias) == (out_channel * heads,)
                    @test size(gat.a) == (2*out_channel, heads, 1)

                    Y = gat(X)
                    @test size(Y) == (out_channel * heads, 1)

                    g = Zygote.gradient(() -> sum(gat(X)), params(gat))
                    @test length(g.grads) == 5

                    # Test with transposed features
                    Xt = rand(N, in_channel)
                    Y = gat(transpose(Xt))
                    @test size(Y) == (out_channel * heads, 1)
                end
            end
        end

        @testset "layer without graph" begin
            fg = FeaturedGraph(adj, X)
            
            @testset "concat=true" begin
                for heads = [1, 6]
                    gat = GATConv(in_channel=>out_channel, heads=heads, concat=true)
                    @test size(gat.weight) == (out_channel * heads, in_channel)
                    @test size(gat.bias) == (out_channel * heads,)
                    @test size(gat.a) == (2*out_channel, heads, 1)

                    fg_ = gat(fg)
                    Y = node_feature(fg_)
                    @test size(Y) == (out_channel * heads, N)
                    @test_throws AssertionError gat(X)

                    g = Zygote.gradient(() -> sum(node_feature(gat(fg))), params(gat))
                    @test length(g.grads) == 5

                    # Test with transposed features
                    Xt = rand(N, in_channel)
                    fgt = FeaturedGraph(adj, transpose(Xt))
                    fgt_ = gat(fgt)
                    @test size(node_feature(fgt_)) == (out_channel * heads, N)
                end
            end

            @testset "concat=false" begin
                for heads = [1, 6]
                    gat = GATConv(in_channel=>out_channel, heads=heads, concat=false)
                    @test size(gat.weight) == (out_channel * heads, in_channel)
                    @test size(gat.bias) == (out_channel * heads,)
                    @test size(gat.a) == (2*out_channel, heads, 1)

                    fg_ = gat(fg)
                    Y = node_feature(fg_)
                    @test size(Y) == (out_channel * heads, 1)
                    @test_throws AssertionError gat(X)

                    g = Zygote.gradient(() -> sum(node_feature(gat(fg))), params(gat))
                    @test length(g.grads) == 5

                    # Test with transposed features
                    Xt = rand(N, in_channel)
                    fgt = FeaturedGraph(adj, transpose(Xt))
                    fgt_ = gat(fgt)
                    @test size(node_feature(fgt_)) == (out_channel * heads, 1)
                end
            end
        end
    end

    @testset "GatedGraphConv" begin
        num_layers = 3
        @testset "layer with graph" begin
            ggc = GatedGraphConv(adj, out_channel, num_layers)
            @test graph(ggc.fg) == [[2,4], [1,3], [2,4], [1,3]]
            @test size(ggc.weight) == (out_channel, out_channel, num_layers)

            X = rand(in_channel, N)
            Y = ggc(X)
            @test size(Y) == (out_channel, N)

            g = Zygote.gradient(() -> sum(ggc(X)), params(ggc))
            @test length(g.grads) == 13

            # Test with transposed features
            Xt = rand(N, in_channel)
            Y = ggc(transpose(Xt))
            @test size(Y) == (out_channel, N)
        end

        @testset "layer without graph" begin
            ggc = GatedGraphConv(out_channel, num_layers)
            @test size(ggc.weight) == (out_channel, out_channel, num_layers)

            X = rand(in_channel, N)
            fg = FeaturedGraph(adj, X)
            fg_ = ggc(fg)
            @test size(node_feature(fg_)) == (out_channel, N)
            @test_throws AssertionError ggc(X)

            g = Zygote.gradient(() -> sum(node_feature(ggc(fg))), params(ggc))
            @test length(g.grads) == 13

            # Test with transposed features
            Xt = rand(N, in_channel)
            fgt = FeaturedGraph(adj, transpose(Xt))
            fgt_ = ggc(fgt)
            @test size(node_feature(fgt_)) == (out_channel, N)
        end
    end

    @testset "EdgeConv" begin
        @testset "layer with graph" begin
            ec = EdgeConv(adj, Dense(2*in_channel, out_channel))
            @test graph(ec.fg) == [[2,4], [1,3], [2,4], [1,3]]

            X = rand(in_channel, N)
            Y = ec(X)
            @test size(Y) == (out_channel, N)

            g = Zygote.gradient(() -> sum(ec(X)), params(ec))
            @test length(g.grads) == 4

            # Test with transposed features
            Xt = rand(N, in_channel)
            Y = ec(transpose(Xt))
            @test size(Y) == (out_channel, N)
        end

        @testset "layer without graph" begin
            ec = EdgeConv(Dense(2*in_channel, out_channel))

            X = rand(in_channel, N)
            fg = FeaturedGraph(adj, X)
            fg_ = ec(fg)
            @test size(node_feature(fg_)) == (out_channel, N)
            @test_throws AssertionError ec(X)

            g = Zygote.gradient(() -> sum(node_feature(ec(fg))), params(ec))
            @test length(g.grads) == 4

            # Test with transposed features
            Xt = rand(N, in_channel)
            fgt = FeaturedGraph(adj, transpose(Xt))
            fgt_ = ec(fgt)
            @test size(node_feature(fgt_)) == (out_channel, N)
        end
    end
end
