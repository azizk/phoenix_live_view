defmodule Phoenix.LiveViewTest.Support.UploadLive do
  use Phoenix.LiveView

  def render(%{uploads: _} = assigns) do
    ~H"""
    <%= for preflight <- @preflights do %>
      preflight:{inspect(preflight)}
    <% end %>
    <%= for name <- @consumed do %>
      consumed:{name}
    <% end %>
    <form phx-change="validate" phx-submit="save">
      <%= for entry <- @uploads.avatar.entries do %>
        {@prefix}:{entry.client_name}:{entry.progress}%
        channel:{inspect(Phoenix.LiveView.UploadConfig.entry_pid(@uploads.avatar, entry))}
        <%= for msg <- upload_errors(@uploads.avatar) do %>
          config_error:{inspect(msg)}
        <% end %>
        <%= for msg <- upload_errors(@uploads.avatar, entry) do %>
          entry_error:{inspect(msg)}
        <% end %>
        relative path:{entry.client_relative_path}
      <% end %>
      <.live_file_input upload={@uploads.avatar} />
      <button type="submit">save</button>
    </form>
    """
  end

  def render(assigns) do
    ~H"""
    <div>
      loading...
    </div>
    """
  end

  def mount(_params, session, socket) do
    prefix =
      case session do
        %{"prefix" => prefix} -> prefix
        _ -> "lv"
      end

    {:ok, assign(socket, preflights: [], consumed: [], prefix: prefix)}
  end

  def handle_call({:setup, setup_func}, _from, socket) do
    {:reply, :ok, setup_func.(socket)}
  end

  def handle_call({:run, func}, _from, socket), do: func.(socket)

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  ## test helpers

  def inspect_html_safe(term) do
    term
    |> inspect()
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  def exits_with(lv, upload, kind, func) do
    Process.unlink(proxy_pid(lv))
    Process.unlink(upload.pid)

    try do
      func.()
      raise "expected to exit with #{inspect(kind)}"
    catch
      :exit, {{%mod{message: msg}, _}, _} when mod == kind -> msg
    end
  end

  def run(lv, func) do
    GenServer.call(lv.pid, {:run, func})
  end

  def proxy_pid(%{proxy: {_ref, _topic, pid}}), do: pid
end

defmodule Phoenix.LiveViewTest.Support.NestedUploadLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    {live_render(@socket, Phoenix.LiveViewTest.Support.UploadLive,
      id: "upload",
      session: %{"prefix" => "nested_lv"}
    )}
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end

defmodule Phoenix.LiveViewTest.Support.UploadComponent do
  use Phoenix.LiveComponent

  def render(%{uploads: _} = assigns) do
    ~H"""
    <div>
      <%= for preflight <- @preflights do %>
        preflight:{inspect(preflight)}
      <% end %>
      <%= for name <- @consumed do %>
        consumed:{name}
      <% end %>
      <%= for msg <- upload_errors(@uploads.avatar) do %>
        config_error:{inspect(msg)}
      <% end %>
      <form phx-change="validate" id={@id} phx-submit="save" phx-target={@myself}>
        <%= for entry <- @uploads.avatar.entries do %>
          component:{entry.client_name}:{entry.progress}%
          channel:{inspect(Phoenix.LiveView.UploadConfig.entry_pid(@uploads.avatar, entry))}
          <%= for msg <- upload_errors(@uploads.avatar, entry) do %>
            entry_error:{inspect(msg)}
          <% end %>
        <% end %>
        <.live_file_input upload={@uploads.avatar} />
        <button type="submit">save</button>
      </form>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div>
      loading...
    </div>
    """
  end

  def update(assigns, socket) do
    new_socket =
      case assigns[:run] do
        {func, from} ->
          {:reply, reply, new_socket} = func.(socket)
          if from, do: GenServer.reply(from, reply)
          new_socket

        nil ->
          socket

        other ->
          {:other, other}
      end

    {:ok,
     new_socket
     |> assign(preflights: [])
     |> assign(consumed: [])
     |> assign(assigns)}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end
end

defmodule Phoenix.LiveViewTest.Support.UploadLiveWithComponent do
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    <div>
      <%= if @uploads_count > 0 do %>
        <%= for i <- 0..@uploads_count do %>
          <.live_component module={Phoenix.LiveViewTest.Support.UploadComponent} id={"upload#{i}"} />
        <% end %>
      <% end %>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, uploads_count: 1)}
  end

  def handle_call({:setup, setup_func}, _from, socket) do
    {:reply, :ok, setup_func.(socket)}
  end

  def handle_call({:uploads, count}, _from, socket) do
    {:reply, :ok, assign(socket, :uploads_count, count)}
  end

  def handle_call({:run, func}, from, socket) do
    send_update(Phoenix.LiveViewTest.Support.UploadComponent, id: "upload0", run: {func, from})
    {:noreply, socket}
  end
end
